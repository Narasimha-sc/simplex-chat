SET search_path TO test_chat_schema;
SET session_replication_role = replica;
BEGIN;
INSERT INTO users (user_id, agent_user_id, contact_id, local_display_name, active_user, created_at, updated_at) OVERRIDING SYSTEM VALUE
VALUES (1, 1, 1, 'big', 0, now(), now()), (2, 2, 2, 'small', 1, now(), now());
INSERT INTO contacts (contact_id, user_id, local_display_name, is_user, enable_ntfs, created_at, updated_at) OVERRIDING SYSTEM VALUE
SELECT i, CASE WHEN i = 2 OR i > 3000 THEN 2 ELSE 1 END, 'c' || i, CASE WHEN i <= 2 THEN 1 ELSE 0 END,
       CASE WHEN i % 10 = 0 THEN 0 ELSE 1 END, now(), now()
FROM generate_series(1, 3003) i;
INSERT INTO groups (group_id, user_id, local_display_name, enable_ntfs, created_at, updated_at) OVERRIDING SYSTEM VALUE
SELECT i, CASE WHEN i > 1000 THEN 2 ELSE 1 END, 'g' || i,
       CASE WHEN i % 5 = 0 THEN 2 WHEN i % 7 = 0 THEN 0 ELSE 1 END, now(), now()
FROM generate_series(1, 1002) i;
INSERT INTO chat_items (user_id, contact_id, item_sent, item_ts, item_content, item_text, item_status, created_at, updated_at)
SELECT 1, 3 + (i % 2998), 0, '2026-01-01T00:00:00Z', '{}', 'x',
       CASE WHEN i % 200 = 0 THEN 'rcv_new' ELSE 'rcv_read' END, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'
FROM generate_series(1, 600000) i;
INSERT INTO chat_items (user_id, group_id, item_sent, item_ts, item_content, item_text, item_status, user_mention, created_at, updated_at)
SELECT 1, 1 + (i % 1000), 0, '2026-01-01T00:00:00Z', '{}', 'x',
       CASE WHEN i % 200 = 0 THEN 'rcv_new' ELSE 'rcv_read' END, CASE WHEN i % 600 = 0 THEN 1 ELSE 0 END,
       '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'
FROM generate_series(1, 1400000) i;
INSERT INTO chat_items (user_id, contact_id, group_id, item_sent, item_ts, item_content, item_text, item_status, created_at, updated_at)
SELECT 2, CASE WHEN i % 2 = 0 THEN 3001 + (i % 3) END, CASE WHEN i % 2 = 1 THEN 1001 + (i % 2) END, 0,
       '2026-01-01T00:00:00Z', '{}', 'x', CASE WHEN i % 20 = 0 THEN 'rcv_new' ELSE 'rcv_read' END,
       '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'
FROM generate_series(1, 300) i;
COMMIT;
SET session_replication_role = origin;
VACUUM ANALYZE;
SELECT user_id, count(*), sum(CASE WHEN item_status = 'rcv_new' THEN 1 ELSE 0 END) AS unread FROM chat_items GROUP BY user_id ORDER BY user_id;
