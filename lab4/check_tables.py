import psycopg2

DB_CONFIG = {
    "dbname": "pickup_network",
    "user": "db_user",
    "password": "1234",
    "host": "localhost",
    "port": 5432
}


def check_all_tables():
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    # Получаем список всех таблиц схемы public
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
        ORDER BY table_name;
    """)
    tables = [row[0] for row in cur.fetchall()]

    for table in tables:
        cur.execute(f"SELECT * FROM {table};")
        rows = cur.fetchall()
        colnames = [desc[0] for desc in cur.description]

        print(f"\n{'=' * 25} ТАБЛИЦА: {table.upper()} (Записей: {len(rows)}) {'=' * 25}")
        print(" | ".join(colnames))
        print("-" * 70)
        for row in rows:
            print(row)

    cur.close()
    conn.close()


if __name__ == "__main__":
    check_all_tables()