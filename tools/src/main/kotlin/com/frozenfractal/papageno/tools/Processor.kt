@file:JvmName(name = "Processor")

package com.frozenfractal.papageno.tools

import com.frozenfractal.papageno.common.XenoCantoRecording
import mu.KotlinLogging

fun XenoCantoRecording.isUsable() =
        genus != null && species != null

fun main (args: Array<String>) {
    val db = openDatabase(true)

    logger.info("Loading recordings from database...")
    val recordings = db.select(XenoCantoRecording::class).get().filter(XenoCantoRecording::isUsable).toList()
    logger.info("${recordings.size} usable recordings found")
}

private val logger = KotlinLogging.logger {}