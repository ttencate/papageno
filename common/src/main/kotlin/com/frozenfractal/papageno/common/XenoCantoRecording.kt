package com.frozenfractal.papageno.common

import io.requery.Entity
import io.requery.Key
import io.requery.Transient

@Entity(extendable = false, immutable = true, stateless = true)
data class XenoCantoRecording(
        @get:Key
        val id: Int,
        val url: String,

        val genus: String?,
        val species: String?,
        val subspecies: String?,
        val englishName: String?,

        val licenseUrl: String?,

        val recordist: String?,
        val date: String?,
        val time: String?,
        val latitude: Float?,
        val longitude: Float?,
        val location: String?,
        val country: String?,
        val elevationMeters: Int?,
        val background: String?,

        val fileUrl: String?,
        val sonogramUrl: String?,

        val lengthSeconds: Float?,
        val samplingRateHz: Int?,
        val bitrateBps: Int?,
        val channels: Int?,

        val type: String?,
        val volume: String?,
        val speed: String?,
        val pitch: String?,
        val soundLength: String?,
        val numberOfNotes: String?,
        val variable: String?
) {
    @get:Transient
    val speciesName: String?
        get() = if (genus == null || species == null) {
            null
        } else if (subspecies == null) {
            "$genus $species"
        } else {
            "$genus $species $subspecies"
        }

    @get:Transient
    val hasLocation: Boolean
        get() = latitude != null && longitude != null
}