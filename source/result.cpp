#include <tuple>
#include <vector>

#include "async_postgres.hpp"

struct FieldInfo {
    const char* name;
    bool text;
    Oid type;
};

void async_postgres::create_result_table(GLua::ILuaInterface* lua,
                                         PGresult* result, bool array_result) {
    lua->CreateTable();

    std::vector<FieldInfo> fields;

    // Fields metadata
    lua->CreateTable();
    int nFields = PQnfields(result);
    for (int i = 0; i < nFields; i++) {
        lua->PushNumber(i + 1);

        FieldInfo info = {PQfname(result, i), PQfformat(result, i) == 0,
                          PQftype(result, i)};

        lua->CreateTable();
        lua->PushString(info.name);
        lua->SetField(-2, "name");

        lua->PushNumber(info.type);
        lua->SetField(-2, "type");

        lua->SetTable(-3);
        fields.push_back(info);
    }
    lua->SetField(-2, "fields");

    // Rows
    lua->CreateTable();
    int nTuples = PQntuples(result);
    for (int i = 0; i < nTuples; i++) {
        lua->PushNumber(i + 1);
        lua->CreateTable();
        for (int j = 0; j < nFields; j++) {
            // skip NULL values
            if (!PQgetisnull(result, i, j)) {
                // field name
                if (!array_result) {
                    lua->PushString(fields[j].name);
                } else {
                    lua->PushNumber(j + 1);
                }

                // field value
                lua->PushString(PQgetvalue(result, i, j),
                                PQgetlength(result, i, j));

                lua->SetTable(-3);
            }
        }
        lua->SetTable(-3);
    }
    lua->SetField(-2, "rows");

    lua->PushString(PQcmdStatus(result));
    lua->SetField(-2, "command");

    lua->PushNumber(PQoidValue(result));
    lua->SetField(-2, "oid");
}

#define set_error_field(name, field)                                 \
    {                                                                \
        const char* field_value = PQresultErrorField(result, field); \
        if (field_value) {                                           \
            lua->PushString(field_value);                            \
            lua->SetField(-2, name);                                 \
        }                                                            \
    }

void async_postgres::create_result_error_table(GLua::ILuaInterface* lua,
                                               const PGresult* result) {
    lua->CreateTable();

    lua->PushString(PQresStatus(PQresultStatus(result)));
    lua->SetField(-2, "status");

    set_error_field("severity", PG_DIAG_SEVERITY_NONLOCALIZED);
    set_error_field("sqlState", PG_DIAG_SQLSTATE);
    set_error_field("messagePrimary", PG_DIAG_MESSAGE_PRIMARY);
    set_error_field("messageDetail", PG_DIAG_MESSAGE_DETAIL);
    set_error_field("messageHint", PG_DIAG_MESSAGE_HINT);
    set_error_field("statementPosition", PG_DIAG_STATEMENT_POSITION);
    set_error_field("context", PG_DIAG_CONTEXT);
    set_error_field("schemaName", PG_DIAG_SCHEMA_NAME);
    set_error_field("tableName", PG_DIAG_TABLE_NAME);
    set_error_field("columnName", PG_DIAG_COLUMN_NAME);
    set_error_field("dataType", PG_DIAG_DATATYPE_NAME);
    set_error_field("constraintName", PG_DIAG_CONSTRAINT_NAME);
    set_error_field("sourceFile", PG_DIAG_SOURCE_FILE);
    set_error_field("sourceLine", PG_DIAG_SOURCE_LINE);
    set_error_field("sourceFunction", PG_DIAG_SOURCE_FUNCTION);
}
