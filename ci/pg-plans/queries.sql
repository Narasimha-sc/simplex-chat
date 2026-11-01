SET search_path TO test_chat_schema;
\echo '### Q1 contacts unread count, user 1'
EXPLAIN (ANALYZE, BUFFERS) SELECT COUNT(1) FROM chat_items i JOIN contacts ct USING (contact_id) WHERE i.user_id = 1 AND i.item_status = 'rcv_new' AND (ct.enable_ntfs = 1 OR ct.enable_ntfs IS NULL) AND ct.deleted = 0;
SELECT COUNT(1) AS q1 FROM chat_items i JOIN contacts ct USING (contact_id) WHERE i.user_id = 1 AND i.item_status = 'rcv_new' AND (ct.enable_ntfs = 1 OR ct.enable_ntfs IS NULL) AND ct.deleted = 0;
\echo '### Q2 groups unread count, user 1'
EXPLAIN (ANALYZE, BUFFERS) SELECT COUNT(1) FROM chat_items i JOIN groups g USING (group_id) WHERE i.user_id = 1 AND i.item_status = 'rcv_new' AND (g.enable_ntfs = 1 OR g.enable_ntfs IS NULL OR (g.enable_ntfs = 2 AND i.user_mention = 1));
SELECT COUNT(1) AS q2 FROM chat_items i JOIN groups g USING (group_id) WHERE i.user_id = 1 AND i.item_status = 'rcv_new' AND (g.enable_ntfs = 1 OR g.enable_ntfs IS NULL OR (g.enable_ntfs = 2 AND i.user_mention = 1));
\echo '### Q3 contacts unread count, user 2'
EXPLAIN (ANALYZE, BUFFERS) SELECT COUNT(1) FROM chat_items i JOIN contacts ct USING (contact_id) WHERE i.user_id = 2 AND i.item_status = 'rcv_new' AND (ct.enable_ntfs = 1 OR ct.enable_ntfs IS NULL) AND ct.deleted = 0;
\echo '### Q4 first unread, master form, user 2'
EXPLAIN (ANALYZE, BUFFERS) SELECT MIN(chat_item_id) FROM chat_items WHERE user_id = 2 AND item_status = 'rcv_new';
\echo '### Q5 first unread, GROUP BY form, user 2'
EXPLAIN (ANALYZE, BUFFERS) SELECT MIN(chat_item_id) FROM chat_items WHERE user_id = 2 AND item_status = 'rcv_new' GROUP BY user_id;
\echo '### Q6 first unread, master form, user 1'
EXPLAIN (ANALYZE, BUFFERS) SELECT MIN(chat_item_id) FROM chat_items WHERE user_id = 1 AND item_status = 'rcv_new';
\echo '### Q7 first unread, GROUP BY form, user 1'
EXPLAIN (ANALYZE, BUFFERS) SELECT MIN(chat_item_id) FROM chat_items WHERE user_id = 1 AND item_status = 'rcv_new' GROUP BY user_id;
\echo '### Q8 chat list ChatStats of contacts, user 1'
EXPLAIN (ANALYZE, BUFFERS) SELECT contact_id, COUNT(1) AS UnreadCount, MIN(chat_item_id) AS MinUnread FROM chat_items WHERE user_id = 1 AND contact_id IS NOT NULL AND item_status = 'rcv_new' GROUP BY contact_id;
\echo '### Q9 mark all read, user 2 (rolled back)'
BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE chat_items SET item_status = 'rcv_read', item_viewed = 1, updated_at = now() WHERE user_id = 2 AND item_status = 'rcv_new';
ROLLBACK;
\echo '### Q10 files of a profile (no files: plan only)'
EXPLAIN SELECT f.file_id FROM chat_items i JOIN files f ON f.chat_item_id = i.chat_item_id WHERE i.user_id = 1;
\echo '### Q11 per-contact unread count, user 1, contact 13'
EXPLAIN (ANALYZE, BUFFERS) SELECT COUNT(1) FROM chat_items WHERE user_id = 1 AND contact_id = 13 AND item_status = 'rcv_new';
\echo '### Q12 contact first unread (getContactMinUnreadId_), user 1, contact 13'
EXPLAIN (ANALYZE, BUFFERS) SELECT chat_item_id FROM chat_items WHERE user_id = 1 AND contact_id = 13 AND item_status = 'rcv_new' ORDER BY created_at ASC, chat_item_id ASC LIMIT 1;
\echo '### Q13 message search across chats, user 1, no match'
EXPLAIN (ANALYZE, BUFFERS) SELECT chat_item_id, contact_id, group_id, group_scope_tag, group_scope_group_member_id, note_folder_id FROM chat_items WHERE user_id = 1 AND LOWER(item_text) LIKE '%' || LOWER('zzz') || '%' ORDER BY item_ts DESC, chat_item_id DESC LIMIT 100;
\echo '### Q14 mark all read, user 1 (rolled back)'
BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE chat_items SET item_status = 'rcv_read', item_viewed = 1, updated_at = now() WHERE user_id = 1 AND item_status = 'rcv_new';
ROLLBACK;
\echo '### Q15 user deletion, user 2 (rolled back)'
BEGIN;
EXPLAIN (ANALYZE, BUFFERS) DELETE FROM users WHERE user_id = 2;
ROLLBACK;
