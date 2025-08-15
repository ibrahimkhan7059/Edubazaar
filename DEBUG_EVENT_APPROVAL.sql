-- Debug query to check requiresApproval field in events
SELECT 
  id,
  title,
  requires_approval,
  is_public,
  organizer_id,
  created_at
FROM events 
ORDER BY created_at DESC 
LIMIT 10;

-- If you want to fix existing events that have requiresApproval = true incorrectly:
-- UPDATE events SET requires_approval = false WHERE requires_approval = true; 