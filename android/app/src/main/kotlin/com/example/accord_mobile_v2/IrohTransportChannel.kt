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
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

class IrohTransportChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "accord/iroh_transport")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        installAndroidContextOnce(activity)
        channel.setMethodCallHandler(::handleMethodCall)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "reset" -> {
                IrohEndpointStore.reset()
                result.success(null)
            }
            "healthCheck" -> healthCheck(call, result)
            "request" -> request(call, result)
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
        if (ticket.isEmpty()) {
            result.error("iroh_invalid_ticket", "Iroh endpoint ticket is empty", null)
            return
        }

        scope.launch {
            try {
                val response = runHttpRequest(ticket, method, path, headers, body)
                postSuccess(result, response)
            } catch (error: IrohTicketException) {
                postError(result, "iroh_invalid_ticket", error.message ?: "Invalid Iroh ticket")
            } catch (error: Throwable) {
                postError(result, "iroh_request_failed", error.message ?: error.toString())
            }
        }
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
                    try {
                        connection.close(0, "done".toByteArray(StandardCharsets.UTF_8))
                    } catch (_: Throwable) {
                    }
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
    ): Map<String, Any?> {
        val endpointAddr = decodeEndpointTicket(ticket).toEndpointAddr()
        val endpoint = IrohEndpointStore.endpoint()
        val startedNs = System.nanoTime()

        try {
            val connection = endpoint.connect(endpointAddr, ALPN)
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
                try {
                    connection.close(0, "done".toByteArray(StandardCharsets.UTF_8))
                } catch (_: Throwable) {
                }
            }
        } catch (error: Throwable) {
            IrohEndpointStore.reset(endpoint)
            throw error
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

private object IrohEndpointStore {
    @Volatile
    private var cachedEndpoint: Endpoint? = null

    fun endpoint(): Endpoint {
        cachedEndpoint?.let { return it }
        return synchronized(this) {
            cachedEndpoint ?: Endpoint.bind(
                EndpointOptions(
                    preset = presetN0(),
                    alpns = listOf(IrohTransportChannelAlpn.ALPN),
                ),
            ).also { cachedEndpoint = it }
        }
    }

    fun reset(endpoint: Endpoint) {
        synchronized(this) {
            if (cachedEndpoint !== endpoint) {
                return
            }
            cachedEndpoint = null
        }
        endpoint.shutdown()
        endpoint.close()
    }

    fun reset() {
        val endpoint = synchronized(this) {
            cachedEndpoint.also { cachedEndpoint = null }
        } ?: return
        endpoint.shutdown()
        endpoint.close()
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
        val usableAddresses = if (relayUrl == null) {
            addresses
        } else {
            emptyList()
        }
        return EndpointAddr(
            EndpointId.fromString(endpointId),
            relayUrl,
            usableAddresses,
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
