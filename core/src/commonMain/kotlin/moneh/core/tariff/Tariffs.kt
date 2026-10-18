package moneh.core.tariff

import kotlinx.serialization.json.Json

object Tariffs {
    private val json = Json { ignoreUnknownKeys = false }

    fun parse(text: String): Tariff = json.decodeFromString(Tariff.serializer(), text)

    /** Tariffs shipped with the app, keyed by id. */
    val bundled: Map<String, Tariff> by lazy {
        bundledTariffJson.mapValues { (file, text) -> parse(text).also { require(it.id == file) { "File $file holds tariff ${it.id}" } } }
    }
}
