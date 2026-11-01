SET search_path TO test_chat_schema;
\echo '### Q9 mark all read, user 2 (rolled back)'
BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE chat_items SET item_status = 'rcv_read', item_viewed = 1, updated_at = now() WHERE user_id = 2 AND item_status = 'rcv_new';
ROLLBACK;
\echo '### Q14 mark all read, user 1 (rolled back)'
BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE chat_items SET item_status = 'rcv_read', item_viewed = 1, updated_at = now() WHERE user_id = 1 AND item_status = 'rcv_new';
ROLLBACK;
\echo '### Q15 user deletion, user 2 (rolled back)'
BEGIN;
EXPLAIN (ANALYZE, BUFFERS) DELETE FROM users WHERE user_id = 2;
ROLLBACK;
