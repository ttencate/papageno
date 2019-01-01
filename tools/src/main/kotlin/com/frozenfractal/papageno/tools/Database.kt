package com.frozenfractal.papageno.tools

import io.requery.sql.KotlinConfiguration
import io.requery.sql.KotlinEntityDataStore
import io.requery.sql.SchemaModifier
import io.requery.sql.TableCreationMode
import org.sqlite.SQLiteConfig
import org.sqlite.SQLiteDataSource


fun openDatabase(createTables: Boolean = false): KotlinEntityDataStore<Any> {
    val sqliteConfig = SQLiteConfig()
    val dataSource = SQLiteDataSource(sqliteConfig)
    dataSource.url = "jdbc:sqlite:db.sqlite3"
    val model = com.frozenfractal.papageno.common.Models.DEFAULT
    val kotlinConfig = KotlinConfiguration(dataSource = dataSource, model = model)
    val db = KotlinEntityDataStore<Any>(kotlinConfig)

    if (createTables) {
        SchemaModifier(dataSource, model).createTables(TableCreationMode.CREATE_NOT_EXISTS)
    }

    return db
}