@file:JvmName(name = "Processor")

package com.frozenfractal.papageno.tools

import com.frozenfractal.papageno.common.KdTree
import com.frozenfractal.papageno.common.KdTreeParams
import com.frozenfractal.papageno.common.XenoCantoRecording
import mu.KotlinLogging

fun XenoCantoRecording.isUsable() =
        genus != null && species != null

fun main(args: Array<String>) {
    val db = openDatabase(true)

    logger.info("Loading recordings from database...")
    val recordings = db
            .select(XenoCantoRecording::class)
            .get()
            .filter(XenoCantoRecording::isUsable)
            .toList()
    logger.info("${recordings.size} usable recordings found")

    logger.info("Constructing k-d trees...")
    val recordingsBySpeciesName = recordings
            .filter(XenoCantoRecording::hasLocation)
            .groupBy(XenoCantoRecording::speciesName)
    val params = KdTreeParams(minRecordingsPerNode = 10, maxLevel = 8)
    var totalSize = 0
    for (entry in recordingsBySpeciesName) {
        val tree = KdTree.fromRecordings(entry.value, params)
        totalSize += tree.serialize().size
    }
    logger.info("Total tree size: $totalSize")
}

private val logger = KotlinLogging.logger {}