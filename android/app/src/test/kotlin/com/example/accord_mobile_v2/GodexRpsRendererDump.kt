package com.example.accord_mobile_v2

import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths

object GodexRpsRendererDump {
    @JvmStatic
    fun main(args: Array<String>) {
        val request = UsbRpsPrintRequest(
            epc = "RPS-USB-TEST",
            itemCode = "USB-TEST",
            itemName = "USB printer test",
            warehouse = "RPS USB TEST",
            printer = "godex",
            printMode = "label",
            grossQty = 1.0,
            unit = "kg",
            tareEnabled = false,
            tareKg = 0.0,
            printCount = 1,
        )
        val output = Paths.get(
            args.firstOrNull()
                ?: System.getProperty(
                    "accord.godex.dump",
                    "/tmp/accord-godex-rps-test.bin",
                ),
        )
        Files.createDirectories(output.parent ?: Path.of("."))
        Files.write(output, GodexRpsRenderer.render(request))
        println(
            "Godex RPS label dumped: ${output.toAbsolutePath()} " +
                "(${Files.size(output)} bytes)",
        )
    }
}
