package com.example.accord_mobile_v2

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Base64
import computer.iroh.Endpoint
import computer.iroh.EndpointAddr
import computer.iroh.EndpointId
import computer.iroh.EndpointOptions
import computer.iroh.IrohAndroid
import computer.iroh.presetN0
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.nio.charset.StandardCharsets
import java.security.SecureRandom
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

class IrohTransportChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "accord/iroh_transport")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val liveJobs = ConcurrentHashMap<Int, Job>()

    init {
        installAndroidContextOnce(activity)
        channel.setMethodCallHandler(::handleMethodCall)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "reset" -> {
                scope.launch {
                    IrohEndpointStore.reset()
                    postSuccess(result, null)
                }
            }
            "healthCheck" -> healthCheck(call, result)
            "request" -> request(call, result)
            "startLive" -> startLive(call, result)
            "stopLive" -> stopLive(call, result)
            else -> result.notImplemented()
        }
    }

    private fun healthCheck(call: MethodCall, result: MethodChannel.Result) {
        val ticket = call.argument<String>("ticket")?.trim().orEmpty()
        val runs = max(call.argument<Int>("runs") ?: 1, 1)
        if (ticket.isEmpty()) {
            result.error("iroh_invalid_ticket", "Iroh endpoint ticket is empty", null)
            return
        }

        scope.launch {
            try {
                val response = runHealthCheck(ticket, runs)
                postSuccess(result, response)
            } catch (error: IrohTicketException) {
                postError(result, "iroh_invalid_ticket", error.message ?: "Invalid Iroh ticket")
            } catch (error: Throwable) {
                postError(result, "iroh_connect_failed", error.message ?: error.toString())
            }
        }
    }

    private fun request(call: MethodCall, result: MethodChannel.Result) {
        val ticket = call.argument<String>("ticket")?.trim().orEmpty()
        val method = call.argument<String>("method")?.trim().orEmpty().ifEmpty { "GET" }
        val path = call.argument<String>("path")?.trim().orEmpty().ifEmpty { "/" }
        val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
        val body = call.argument<ByteArray>("body") ?: ByteArray(0)
        val reuseConnection = call.argument<Boolean>("reuseConnection") ?: false
        if (ticket.isEmpty()) {
            result.error("iroh_invalid_ticket", "Iroh endpoint ticket is empty", null)
            return
        }

        scope.launch {
            try {
                val response = runHttpRequest(ticket, method, path, headers, body, reuseConnection)
                postSuccess(result, response)
            } catch (error: IrohTicketException) {
                postError(result, "iroh_invalid_ticket", error.message ?: "Invalid Iroh ticket")
            } catch (error: Throwable) {
                postError(result, "iroh_request_failed", error.message ?: error.toString())
            }
        }
    }

    private fun startLive(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Int>("id") ?: 0
        val ticket = call.argument<String>("ticket")?.trim().orEmpty()
        val path = call.argument<String>("path")?.trim().orEmpty().ifEmpty { "/" }
        val reuseConnection = call.argument<Boolean>("reuseConnection") ?: false
        val sendPings = call.argument<Boolean>("sendPings") ?: false
        if (id <= 0 || ticket.isEmpty()) {
            result.error("iroh_live_failed", "Invalid live stream arguments", null)
            return
        }

        liveJobs.remove(id)?.cancel()
        liveJobs[id] = scope.launch {
            try {
                runLiveRequest(id, ticket, path, reuseConnection, sendPings)
                emitLiveClosed(id)
            } catch (error: Throwable) {
                emitLiveError(id, error.message ?: error.toString())
            } finally {
                liveJobs.remove(id)
            }
        }
        result.success(null)
    }

    private fun stopLive(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Int>("id") ?: 0
        liveJobs.remove(id)?.cancel()
        result.success(null)
    }

    private suspend fun runHealthCheck(ticket: String, runs: Int): Map<String, Any?> {
        val endpointAddr = decodeEndpointTicket(ticket).toEndpointAddr()
        val endpoint = IrohEndpointStore.endpoint()

        var statusCode = 0
        var bytes = 0
        var pathInfo = ""
        val startedNs = System.nanoTime()
        try {
            repeat(runs) {
                val connection = endpoint.connect(endpointAddr, ALPN)
                try {
                    val bi = connection.openBi()
                    val send = bi.send()
                    val recv = bi.recv()

                    send.writeAll(HEALTH_REQUEST)
                    send.finish()

                    val response = recv.readToEnd(MAX_HTTP_BYTES.toUInt())
                    statusCode = parseStatusCode(response)
                    bytes = response.size
                    pathInfo = connection.paths().joinToString(" | ") { path ->
                        val kind = if (path.isRelay) {
                            "relay"
                        } else if (path.isIp) {
                            "direct"
                        } else {
                            "?"
                        }
                        val selected = if (path.isSelected) "* " else ""
                        "$selected$kind ${path.remoteAddr} ${path.rttMs}ms"
                    }
                    if (statusCode != 200) {
                        throw IllegalStateException(
                            "unexpected HTTP status $statusCode: ${
                                String(response, StandardCharsets.UTF_8)
                            }",
                        )
                    }
                } finally {
                    closeConnection(connection, "done")
                }
            }
        } catch (error: Throwable) {
            IrohEndpointStore.reset(endpoint)
            throw error
        }

        val totalMs = (System.nanoTime() - startedNs).toDouble() / 1_000_000.0
        return mapOf(
            "ok" to true,
            "statusCode" to statusCode,
            "runs" to runs,
            "bytes" to bytes,
            "totalMs" to totalMs,
            "pathInfo" to pathInfo,
        )
    }

    private suspend fun runHttpRequest(
        ticket: String,
        method: String,
        path: String,
        headers: Map<String, String>,
        body: ByteArray,
        reuseConnection: Boolean,
    ): Map<String, Any?> {
        val endpointAddr = decodeEndpointTicket(ticket).toEndpointAddr()
        val startedNs = System.nanoTime()

        try {
            val connection = if (reuseConnection) {
                IrohEndpointStore.connection(ticket, endpointAddr)
            } else {
                IrohEndpointStore.endpoint().connect(endpointAddr, ALPN)
            }
            try {
                val bi = connection.openBi()
                val send = bi.send()
                val recv = bi.recv()

                send.writeAll(buildHttpRequest(method, path, headers, body))
                send.finish()

                val response = recv.readToEnd(MAX_HTTP_BYTES.toUInt())
                val parsed = parseHttpResponse(response)
                val totalMs = (System.nanoTime() - startedNs).toDouble() / 1_000_000.0
                val pathInfo = connection.paths().joinToString(" | ") { pathEntry ->
                    val kind = if (pathEntry.isRelay) {
                        "relay"
                    } else if (pathEntry.isIp) {
                        "direct"
                    } else {
                        "?"
                    }
                    val selected = if (pathEntry.isSelected) "* " else ""
                    "$selected$kind ${pathEntry.remoteAddr} ${pathEntry.rttMs}ms"
                }
                return mapOf(
                    "statusCode" to parsed.statusCode,
                    "headers" to parsed.headers,
                    "body" to parsed.body,
                    "totalMs" to totalMs,
                    "pathInfo" to pathInfo,
                )
            } finally {
                if (!reuseConnection) {
                    closeConnection(connection, "done")
                }
            }
        } catch (error: Throwable) {
            if (reuseConnection) {
                IrohEndpointStore.resetConnection(ticket)
            }
            throw error
        }
    }

    private suspend fun runLiveRequest(
        id: Int,
        ticket: String,
        path: String,
        reuseConnection: Boolean,
        sendPings: Boolean,
    ) {
        val endpointAddr = decodeEndpointTicket(ticket).toEndpointAddr()
        val connection = if (reuseConnection) {
            IrohEndpointStore.connection(ticket, endpointAddr)
        } else {
            IrohEndpointStore.endpoint().connect(endpointAddr, ALPN)
        }
        try {
            val bi = connection.openBi()
            val send = bi.send()
            val recv = bi.recv()
            val writer = IrohLiveWriter(send)
            writer.write(buildWebSocketUpgradeRequest(path))

            val response = readWebSocketResponseHead(recv)
            val parsed = parseHttpResponse(response.first)
            if (parsed.statusCode != 101) {
                throw IllegalStateException(
                    "unexpected WebSocket status ${parsed.statusCode}: ${
                        String(parsed.body, StandardCharsets.UTF_8)
                    }",
                )
            }

            val pingJob = if (sendPings) {
                scope.launch {
                    var pingId = 0
                    while (isActive) {
                        pingId += 1
                        val payload =
                            """{"type":"ping","id":$pingId,"sent_at_ms":${System.currentTimeMillis()}}"""
                        try {
                            writer.write(buildWebSocketFrame(0x1, payload.toByteArray(StandardCharsets.UTF_8)))
                        } catch (_: Throwable) {
                            break
                        }
                        delay(2_000)
                    }
                }
            } else {
                null
            }

            try {
                val frameBuffer = WebSocketFrameBuffer()
                frameBuffer.append(response.second)
                drainWebSocketFrames(id, frameBuffer, writer)
                while (currentCoroutineContext().isActive) {
                    val chunk = recv.read((16 * 1024).toUInt())
                    if (chunk.isEmpty()) {
                        break
                    }
                    frameBuffer.append(chunk)
                    drainWebSocketFrames(id, frameBuffer, writer)
                }
            } finally {
                pingJob?.cancel()
                writer.finish()
            }
        } finally {
            if (!reuseConnection) {
                closeConnection(connection, "done")
            }
        }
    }

    private suspend fun readWebSocketResponseHead(
        recv: computer.iroh.RecvStream,
    ): Pair<ByteArray, ByteArray> {
        val marker = "\r\n\r\n".toByteArray(StandardCharsets.UTF_8)
        val buffer = ByteArrayOutputStream()
        while (true) {
            val chunk = recv.read(4096u)
            if (chunk.isEmpty()) {
                throw IllegalStateException("WebSocket response ended before headers")
            }
            buffer.write(chunk)
            val bytes = buffer.toByteArray()
            val headerEnd = bytes.indexOf(marker)
            if (headerEnd >= 0) {
                return bytes.copyOfRange(0, headerEnd + marker.size) to
                    bytes.copyOfRange(headerEnd + marker.size, bytes.size)
            }
            if (bytes.size > 64 * 1024) {
                throw IllegalStateException("WebSocket response headers exceed size limit")
            }
        }
    }

    private suspend fun drainWebSocketFrames(
        id: Int,
        frameBuffer: WebSocketFrameBuffer,
        writer: IrohLiveWriter,
    ) {
        while (true) {
            val frame = frameBuffer.pop() ?: return
            when (frame.opcode) {
                0x1 -> emitLiveMessage(id, String(frame.payload, StandardCharsets.UTF_8))
                0x8 -> {
                    runCatching { writer.write(buildWebSocketFrame(0x8, frame.payload)) }
                    return
                }
                0x9 -> writer.write(buildWebSocketFrame(0xA, frame.payload))
            }
        }
    }

    private fun emitLiveMessage(id: Int, text: String) {
        mainHandler.post {
            channel.invokeMethod("liveMessage", mapOf("id" to id, "text" to text))
        }
    }

    private fun emitLiveError(id: Int, message: String) {
        mainHandler.post {
            channel.invokeMethod("liveError", mapOf("id" to id, "message" to message))
        }
    }

    private fun emitLiveClosed(id: Int) {
        mainHandler.post {
            channel.invokeMethod("liveClosed", mapOf("id" to id))
        }
    }

    private fun postSuccess(result: MethodChannel.Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post { result.error(code, message, null) }
    }

    companion object {
        private val androidContextInstalled = AtomicBoolean(false)
        private val ALPN = "/mini-rs-erp/http/1".toByteArray(StandardCharsets.UTF_8)
        private val HEALTH_REQUEST =
            "GET /healthz HTTP/1.1\r\nHost: mini-rs-erp\r\nConnection: close\r\n\r\n"
                .toByteArray(StandardCharsets.UTF_8)
        private const val MAX_HTTP_BYTES = 2 * 1024 * 1024

        private fun installAndroidContextOnce(activity: Activity) {
            if (androidContextInstalled.compareAndSet(false, true)) {
                IrohAndroid.installAndroidContext(activity.applicationContext)
            }
        }
    }
}

private class IrohLiveWriter(
    private val send: computer.iroh.SendStream,
) {
    private val lock = Mutex()

    suspend fun write(data: ByteArray) {
        lock.withLock {
            send.writeAll(data)
        }
    }

    suspend fun finish() {
        runCatching {
            lock.withLock {
                send.finish()
            }
        }
    }
}

private data class WebSocketFrame(
    val opcode: Int,
    val payload: ByteArray,
)

private class WebSocketFrameBuffer {
    private val buffer = ArrayList<Byte>()

    fun append(bytes: ByteArray) {
        for (byte in bytes) {
            buffer.add(byte)
        }
    }

    fun pop(): WebSocketFrame? {
        if (buffer.size < 2) {
            return null
        }
        val first = buffer[0].toInt() and 0xff
        val second = buffer[1].toInt() and 0xff
        val opcode = first and 0x0f
        val masked = (second and 0x80) != 0
        var length = second and 0x7f
        var offset = 2

        if (length == 126) {
            if (buffer.size < offset + 2) {
                return null
            }
            length = ((buffer[offset].toInt() and 0xff) shl 8) or
                (buffer[offset + 1].toInt() and 0xff)
            offset += 2
        } else if (length == 127) {
            if (buffer.size < offset + 8) {
                return null
            }
            var longLength = 0L
            repeat(8) {
                longLength = (longLength shl 8) or (buffer[offset + it].toLong() and 0xff)
            }
            if (longLength > Int.MAX_VALUE) {
                throw IllegalStateException("WebSocket frame too large")
            }
            length = longLength.toInt()
            offset += 8
        }

        val mask = ByteArray(4)
        if (masked) {
            if (buffer.size < offset + 4) {
                return null
            }
            repeat(4) {
                mask[it] = buffer[offset + it]
            }
            offset += 4
        }

        if (buffer.size < offset + length) {
            return null
        }
        val payload = ByteArray(length)
        repeat(length) { index ->
            var byte = buffer[offset + index]
            if (masked) {
                byte = (byte.toInt() xor mask[index % 4].toInt()).toByte()
            }
            payload[index] = byte
        }
        repeat(offset + length) {
            buffer.removeAt(0)
        }
        return WebSocketFrame(opcode, payload)
    }
}

private object IrohEndpointStore {
    private val endpointLock = Mutex()
    private val connectionLock = Mutex()
    @Volatile
    private var cachedEndpoint: Endpoint? = null
    @Volatile
    private var cachedConnection: computer.iroh.Connection? = null
    @Volatile
    private var cachedConnectionTicket: String? = null

    suspend fun endpoint(): Endpoint {
        cachedEndpoint?.let { return it }
        return endpointLock.withLock {
            cachedEndpoint ?: Endpoint.bind(
                EndpointOptions(
                    preset = presetN0(),
                    alpns = listOf(IrohTransportChannelAlpn.ALPN),
                ),
            ).also { cachedEndpoint = it }
        }
    }

    suspend fun connection(ticket: String, addr: EndpointAddr): computer.iroh.Connection {
        return connectionLock.withLock {
            val connection = cachedConnection
            if (connection != null && cachedConnectionTicket == ticket) {
                return@withLock connection
            }
            val newConnection = endpoint().connect(addr, IrohTransportChannelAlpn.ALPN)
            cachedConnection = newConnection
            cachedConnectionTicket = ticket
            newConnection
        }
    }

    suspend fun resetConnection(ticket: String) {
        val connection = connectionLock.withLock {
            if (cachedConnectionTicket != ticket) {
                return
            }
            cachedConnection.also {
                cachedConnection = null
                cachedConnectionTicket = null
            }
        }
        closeConnection(connection, "reset")
    }

    suspend fun reset(endpoint: Endpoint) {
        val connection = connectionLock.withLock {
            if (cachedEndpoint !== endpoint) {
                return
            }
            val connection = cachedConnection
            cachedEndpoint = null
            cachedConnection = null
            cachedConnectionTicket = null
            connection
        }
        closeConnection(connection, "reset")
        endpoint.shutdown()
        endpoint.close()
    }

    suspend fun reset() {
        val snapshot = connectionLock.withLock {
            val endpoint = cachedEndpoint
            val connection = cachedConnection
            cachedEndpoint = null
            cachedConnection = null
            cachedConnectionTicket = null
            endpoint to connection
        }
        closeConnection(snapshot.second, "reset")
        val endpoint = snapshot.first ?: return
        endpoint.shutdown()
        endpoint.close()
    }

    private fun closeConnection(connection: computer.iroh.Connection?, reason: String) {
        if (connection == null) {
            return
        }
        try {
            connection.close(0, reason.toByteArray(StandardCharsets.UTF_8))
        } catch (_: Throwable) {
        }
    }
}

private val webSocketRandom = SecureRandom()

private fun buildWebSocketUpgradeRequest(path: String): ByteArray {
    val keyBytes = ByteArray(16)
    webSocketRandom.nextBytes(keyBytes)
    val key = Base64.encodeToString(keyBytes, Base64.NO_WRAP)
    return buildString {
        append("GET ").append(path).append(" HTTP/1.1\r\n")
        append("Host: mini-rs-erp\r\n")
        append("Connection: Upgrade\r\n")
        append("Upgrade: websocket\r\n")
        append("Sec-WebSocket-Version: 13\r\n")
        append("Sec-WebSocket-Key: ").append(key).append("\r\n")
        append("\r\n")
    }.toByteArray(StandardCharsets.UTF_8)
}

private fun buildWebSocketFrame(opcode: Int, payload: ByteArray): ByteArray {
    val output = ByteArrayOutputStream()
    output.write(0x80 or (opcode and 0x0f))
    when {
        payload.size <= 125 -> output.write(0x80 or payload.size)
        payload.size <= UShort.MAX_VALUE.toInt() -> {
            output.write(0x80 or 126)
            output.write((payload.size shr 8) and 0xff)
            output.write(payload.size and 0xff)
        }
        else -> {
            output.write(0x80 or 127)
            val length = payload.size.toLong()
            for (shift in 56 downTo 0 step 8) {
                output.write(((length shr shift) and 0xff).toInt())
            }
        }
    }
    val mask = ByteArray(4)
    webSocketRandom.nextBytes(mask)
    output.write(mask)
    payload.forEachIndexed { index, byte ->
        output.write(byte.toInt() xor mask[index % 4].toInt())
    }
    return output.toByteArray()
}

private fun closeConnection(connection: computer.iroh.Connection, reason: String) {
    try {
        connection.close(0, reason.toByteArray(StandardCharsets.UTF_8))
    } catch (_: Throwable) {
    }
}

private object IrohTransportChannelAlpn {
    val ALPN: ByteArray = "/mini-rs-erp/http/1".toByteArray(StandardCharsets.UTF_8)
}

private data class DecodedEndpointTicket(
    val endpointId: String,
    val relayUrl: String?,
    val addresses: List<String>,
) {
    fun toEndpointAddr(): EndpointAddr {
        return EndpointAddr(
            EndpointId.fromString(endpointId),
            relayUrl,
            addresses,
        )
    }
}

private class IrohTicketException(message: String) : Exception(message)

private fun decodeEndpointTicket(ticket: String): DecodedEndpointTicket {
    val json = try {
        val bytes = Base64.decode(
            ticket,
            Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP,
        )
        JSONObject(String(bytes, StandardCharsets.UTF_8))
    } catch (error: Throwable) {
        throw IrohTicketException("Iroh endpoint ticket decode failed")
    }

    val endpointId = json.optString("id").trim()
    if (endpointId.isEmpty()) {
        throw IrohTicketException("Iroh endpoint id is missing")
    }

    val addresses = mutableListOf<String>()
    var relayUrl: String? = null
    val addrs = json.optJSONArray("addrs") ?: JSONArray()
    for (index in 0 until addrs.length()) {
        val entry = addrs.opt(index)
        if (entry is JSONObject) {
            entry.optString("Ip").trim().takeIf { it.isNotEmpty() }?.let(addresses::add)
            entry.optString("ip").trim().takeIf { it.isNotEmpty() }?.let(addresses::add)
            val relay = entry.optString("Relay").trim().ifEmpty {
                entry.optString("relay").trim()
            }
            if (relay.isNotEmpty()) {
                relayUrl = relay
            }
        } else if (entry is String && entry.isNotBlank()) {
            addresses.add(entry.trim())
        }
    }

    return DecodedEndpointTicket(
        endpointId = endpointId,
        relayUrl = relayUrl,
        addresses = addresses.distinct(),
    )
}

private fun parseStatusCode(response: ByteArray): Int {
    val line = String(response, StandardCharsets.UTF_8).lineSequence().firstOrNull()
        ?: return 0
    return line.split(' ').getOrNull(1)?.toIntOrNull() ?: 0
}

private data class ParsedHttpResponse(
    val statusCode: Int,
    val headers: Map<String, String>,
    val body: ByteArray,
)

private fun buildHttpRequest(
    method: String,
    path: String,
    headers: Map<String, String>,
    body: ByteArray,
): ByteArray {
    val request = StringBuilder()
    request.append(method.uppercase()).append(' ').append(path).append(" HTTP/1.1\r\n")
    request.append("Host: mini-rs-erp\r\n")
    request.append("Connection: close\r\n")
    headers.forEach { (name, value) ->
        val lowercased = name.lowercase()
        if (lowercased != "host" &&
            lowercased != "connection" &&
            lowercased != "content-length"
        ) {
            request.append(name).append(": ").append(value).append("\r\n")
        }
    }
    if (body.isNotEmpty()) {
        request.append("Content-Length: ").append(body.size).append("\r\n")
    }
    request.append("\r\n")
    return request.toString().toByteArray(StandardCharsets.UTF_8) + body
}

private fun parseHttpResponse(response: ByteArray): ParsedHttpResponse {
    val marker = "\r\n\r\n".toByteArray(StandardCharsets.UTF_8)
    val headerEnd = response.indexOf(marker)
    val headerBytes: ByteArray
    val bodyBytes: ByteArray
    if (headerEnd >= 0) {
        headerBytes = response.copyOfRange(0, headerEnd)
        bodyBytes = response.copyOfRange(headerEnd + marker.size, response.size)
    } else {
        headerBytes = response
        bodyBytes = ByteArray(0)
    }

    val lines = String(headerBytes, StandardCharsets.UTF_8)
        .split("\r\n")
        .filter { it.isNotBlank() }
    val statusCode = lines.firstOrNull()
        ?.split(' ')
        ?.getOrNull(1)
        ?.toIntOrNull() ?: 0
    val headers = mutableMapOf<String, String>()
    lines.drop(1).forEach { line ->
        val separator = line.indexOf(':')
        if (separator <= 0) {
            return@forEach
        }
        val name = line.substring(0, separator).trim().lowercase()
        val value = line.substring(separator + 1).trim()
        if (name.isNotEmpty()) {
            headers[name] = value
        }
    }
    return ParsedHttpResponse(statusCode, headers, bodyBytes)
}

private fun ByteArray.indexOf(needle: ByteArray): Int {
    if (needle.isEmpty() || needle.size > size) {
        return -1
    }
    for (index in 0..(size - needle.size)) {
        var matches = true
        for (needleIndex in needle.indices) {
            if (this[index + needleIndex] != needle[needleIndex]) {
                matches = false
                break
            }
        }
        if (matches) {
            return index
        }
    }
    return -1
}
