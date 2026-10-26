import psycopg2
from datetime import datetime, timedelta

# Параметры подключения к PostgreSQL
DB_CONFIG = {
    "dbname": "pickup_network",
    "user": "db_user",
    "password": "1234",
    "host": "localhost",
    "port": 5432
}

def seed_database():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        print(" Успешное подключение к PostgreSQL!")

        # ---------------------------------------------------------------------
        # 1. Заполняем E1. Партнеры
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO partner (org_name, phone, email, status) VALUES 
            ('ООО Озон Маркет', '+79001112233', 'partner1@ozon.fake', 'активен'),
            ('ИП Смирнов Доставка', '+79002223344', 'smirnov@mail.fake', 'активен')
            RETURNING partner_id;
        """)
        partner_ids = [row[0] for row in cur.fetchall()]
        p1_id, p2_id = partner_ids[0], partner_ids[1]

        # ---------------------------------------------------------------------
        # 2. Заполняем E3. Пункты выдачи
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO pickup_point (address, status) VALUES 
            ('г. Москва, ул. Тверская, д. 10', 'работает'),
            ('г. Москва, пр-кт Мира, д. 45', 'работает'),
            ('г. Москва, ул. Ленина, д. 5', 'работает')
            RETURNING point_id;
        """)
        points = [row[0] for row in cur.fetchall()]
        pt1, pt2, pt3 = points[0], points[1], points[2]

        # ---------------------------------------------------------------------
        # 3. Заполняем E7. Реестры передачи
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO transfer_registry (created_at) VALUES 
            (NOW() - INTERVAL '3 days'),
            (NOW() - INTERVAL '1 day')
            RETURNING registry_id;
        """)
        regs = [row[0] for row in cur.fetchall()]
        reg1, reg2 = regs[0], regs[1]

        # ---------------------------------------------------------------------
        # 4. Заполняем E17. Клиенты
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO client (phone, email, full_name, age, status) VALUES 
            ('+79991234567', 'ivanov@yandex.ru', 'Иванов Иван Иванович', 25, 'активен'),
            ('+79998887766', 'petrov@mail.ru', 'Петров Петр Сергеевич', 34, 'активен')
            RETURNING client_id;
        """)
        clients = [row[0] for row in cur.fetchall()]
        client1, client2 = clients[0], clients[1]

        # ---------------------------------------------------------------------
        # 5. Заполняем E2. Договоры партнеров
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO partner_contract (partner_id, start_date, end_date, status) VALUES 
            (%s, CURRENT_DATE - 30, CURRENT_DATE + 335, 'действует'),
            (%s, CURRENT_DATE - 10, CURRENT_DATE + 180, 'действует')
            RETURNING contract_id;
        """, (p1_id, p2_id))
        contracts = [row[0] for row in cur.fetchall()]
        c1, c2 = contracts[0], contracts[1]

        # ---------------------------------------------------------------------
        # 6. Заполняем E4. Места хранения (ячейки)
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO storage_place (point_id, place_id, length_m, width_m, height_m, status) VALUES 
            (%s, 101, 1.200, 0.800, 0.500, 'занято'),
            (%s, 102, 1.500, 1.000, 1.200, 'свободно'),
            (%s, 201, 0.600, 0.600, 0.400, 'занято');
        """, (pt1, pt1, pt2))

        # ---------------------------------------------------------------------
        # 7. Заполняем E8. Курьерские рейсы
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO courier_trip (registry_id, sender_point_id, receiver_point_id, status, departure_time, arrival_time) VALUES 
            (%s, %s, %s, 'завершен', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '3 hours')
            RETURNING trip_id;
        """, (reg1, pt1, pt2))

        # ---------------------------------------------------------------------
        # 8. Заполняем E9. Операции приема
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO receiving_operation (registry_id, start_time, end_time, status) VALUES 
            (%s, NOW() - INTERVAL '40 hours', NOW() - INTERVAL '39 hours', 'проведена')
            RETURNING receiving_op_id;
        """, (reg1,))
        rec_op_id = cur.fetchone()[0]

        # ---------------------------------------------------------------------
        # 9. Заполняем E16. Начисления партнерам
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO partner_payout (contract_id, registry_id, amount_rub, processed_at, status) VALUES 
            (%s, %s, 14500.50, NOW() - INTERVAL '1 day', 'начислено');
        """, (c1, reg1))

        # ---------------------------------------------------------------------
        # 10. Заполняем E5. Отправления (заказы)
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO departure (partner_id, departure_id, registry_id, status, storage_end_date) VALUES 
            (%s, 5001, %s, 'полностью доставлено', CURRENT_DATE + 7),
            (%s, 5002, %s, 'частично доставлено', CURRENT_DATE + 5);
        """, (p1_id, reg1, p2_id, reg2))

        # ---------------------------------------------------------------------
        # 11. Заполняем E10. Размещения
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO placement (point_id, place_id, receiving_op_id, start_time, status) VALUES 
            (%s, 101, %s, NOW() - INTERVAL '38 hours', 'проведено');
        """, (pt1, rec_op_id))

        # ---------------------------------------------------------------------
        # 12. Заполняем E15. Акты расхождения
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO collision_act (receiving_op_id, created_at, status) VALUES 
            (%s, NOW() - INTERVAL '38 hours', 'в силе');
        """, (rec_op_id,))

        # ---------------------------------------------------------------------
        # 13. Заполняем E11. Уведомления
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO notification (client_id, receiving_op_id, message_text, sent_at) VALUES 
            (%s, %s, 'Ваш заказ прибыл в пункт выдачи!', NOW() - INTERVAL '37 hours');
        """, (client1, rec_op_id))

        # ---------------------------------------------------------------------
        # 14. Заполняем E6. Грузовые места
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO cargo_place (partner_id, departure_id, min_age, weight_kg, length_m, width_m, height_m, description) VALUES 
            (%s, 5001, 14, 2.450, 0.400, 0.300, 0.200, 'Ноутбук Lenovo'),
            (%s, 5001, 14, 0.800, 0.200, 0.150, 0.100, 'Чехол и мышь'),
            (%s, 5002, 18, 5.120, 0.800, 0.500, 0.400, 'Набор инструментов')
            RETURNING cargo_place_id;
        """, (p1_id, p1_id, p2_id))
        places = [row[0] for row in cur.fetchall()]
        cp1, cp2, cp3 = places[0], places[1], places[2]

        # ---------------------------------------------------------------------
        # 15. Заполняем E13. Продление хранения
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO storage_extension (partner_id, departure_id, old_end_date, new_end_date, reason) VALUES 
            (%s, 5001, CURRENT_DATE + 7, CURRENT_DATE + 14, 'Просьба клиента по звонку');
        """, (p1_id,))

        # ---------------------------------------------------------------------
        # 16. Заполняем E12. Выдача (коробку №1 выдали клиенту №1)
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO issuance (cargo_place_id, client_id, issued_at, status) VALUES 
            (%s, %s, NOW() - INTERVAL '2 hours', 'проведена');
        """, (cp1, client1))

        # ---------------------------------------------------------------------
        # 17. Заполняем E14. Возврат (коробку №3 оформили на возврат)
        # ---------------------------------------------------------------------
        cur.execute("""
            INSERT INTO return_item (cargo_place_id, return_id, client_id, returned_at, status) VALUES 
            (%s, 1, %s, NOW() - INTERVAL '1 hour', 'проведен');
        """, (cp3, client2))

        # Фиксируем транзакцию
        conn.commit()
        print(" Все 17 таблиц успешно заполнены тестовыми данными!")

    except Exception as e:
        if conn:
            conn.rollback()
        print(f" Ошибка при заполнении: {e}")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()

if __name__ == "__main__":
    seed_database()
