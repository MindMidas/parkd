# Notifications Event Contract

This document defines the canonical event points and payload fields for host notifications.

## Event: reservation_confirmed

- Source table: `public.reservations`
- Source trigger: `trg_notify_host_on_reservation_confirmed`
- Fire condition:
  - `OLD.status` is not `confirmed`
  - `NEW.status` is `confirmed`
- Recipient: reservation host (`reservations.host_id`)
- Notification row fields:
  - `type`: `reservation_confirmed`
  - `title`: `New reservation confirmed`
  - `body`: `A driver has completed payment for your listing.`
  - `source_entity_type`: `reservation`
  - `source_entity_id`: `reservations.id`
  - `data_json`:
    - `reservation_id`
    - `listing_id`
    - `driver_id`
    - `start_time`
    - `end_time`
    - `total_price`
    - `service_fee`

## Event: review_received

- Source table: `public.reviews`
- Source trigger: `trg_notify_host_on_review_received`
- Fire condition:
  - `public.reviews` row inserted
  - `reviews.reviewee_id` equals reservation host for `reviews.reservation_id`
- Recipient: reservation/listing host
- Notification row fields:
  - `type`: `review_received`
  - `title`: `New rating received`
  - `body`: `You received a <n>-star rating on one of your listings.`
  - `source_entity_type`: `review`
  - `source_entity_id`: `reviews.id`
  - `data_json`:
    - `review_id`
    - `reservation_id`
    - `listing_id`
    - `reviewer_id`
    - `rating`

## Event: message_received

- Source table: `public.messages`
- Source trigger: `trg_notify_on_message_received`
- Fire condition:
  - new message inserted for a conversation
  - recipient is inferred as the other conversation participant (not sender)
- Recipient: other participant in the conversation (host or driver)
- Notification row fields:
  - `type`: `message_received`
  - `title`: `New message from <sender_name>`
  - `body`: first 120 chars of message text
  - `source_entity_type`: `message`
  - `source_entity_id`: `messages.id`
  - `data_json`:
    - `message_id`
    - `conversation_id`
    - `reservation_id`
    - `sender_id`
    - `sender_name`
    - `sender_avatar_url` (nullable; from `profiles.avatar_url`)

## Delivery model

- In-app feed reads from `public.notifications`.
- Push dispatcher reads notifications where `push_sent_at is null`.
- Push tokens are read from `public.user_push_tokens`.
- Idempotency is enforced by `notifications_dedupe_event_idx`.
