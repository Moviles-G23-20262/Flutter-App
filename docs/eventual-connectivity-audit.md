# Eventual connectivity audit

The audit covered the Flutter scenarios in Sprint 3. The first pass used the Medium Phone emulator with a local test API. The follow-up traced retries through Flutter and the backend and exercised concurrent writes against disposable PostgreSQL.

## Findings and fixes

| Scenario | Finding and fix |
| --- | --- |
| EC1, EC5–EC6 · Session and connection errors | A temporary API failure could send a signed-in user back to login. Delayed replies from an old session could also sign out a new user or restore a profile after sign-out. The app now restores the saved profile for temporary failures and checks that session replies still belong to the active session. Connection errors use plain language. |
| EC3–EC4, EC14 · Listings, drafts and photos | Publishing could lose upload progress if the app stopped mid-request. The app now queues the listing before sending and saves each completed upload. In the emulator, the draft survived a force-stop and the listing published once using the two photos it had already uploaded. |
| EC7–EC8 · Chat and inbox | The API discarded the client's message ID, so a lost response could create a duplicate bubble. The API now reuses the original message on retry. The app also shows queued messages alongside saved chats, hides stale unread counts, and keeps the exchange shortcut available offline. |
| EC9, EC12 · Meeting proposals | Retrying a lost response could replace the original proposal and post a second card. The queue and API now share a stable ID. After expiry, the app checks whether the proposal already arrived before marking it expired. An expired proposal no longer blocks a new one in the same chat. |
| EC10–EC11 · Exchanges and ratings | The app could send a rating before both parties confirmed. Either party can now confirm, and the queued rating waits until the exchange is complete. Cancellation also checks that the exchange is still pending before releasing the listing. |
| EC13 · Outbox and mobile data | A Wi-Fi to mobile-data handoff could keep sending without permission, and switching accounts could stall the new account's queue. The outbox now checks the connection and session before each queued send. The one-time mobile-data override still works. |
| EC15 · Favorites and notifications | Both screens could wait on unrelated requests. They now load independently, show their saved copies when the connection drops, and roll back only the failed change. |
| EC16 · Analytics configuration | The development config pointed to localhost. Merging `main` brought in the deployed analytics URL. Automated tests covered analytics batching, retry and crash recovery. |
| Backend concurrency · Replies and chat creation | Simultaneous accepts could post duplicate confirmations, acceptance could race with withdrawal, and concurrent opens could create duplicate chat rooms. The API now serializes those operations. |

## Verification and rollout

- **720 Flutter tests and 213 backend tests passed.** The backend build passed.
- PostgreSQL checks verified one chat room for 12 simultaneous opens, one confirmation message for two accepts, one winner for accept versus withdraw, and a completed exchange staying completed when a stale cancellation arrived.
- Production behavior, physical-device fingerprint unlock, and a full visual pass of cached photos and placeholders remain unverified.
- The Flutter and [backend changes](https://github.com/Moviles-G23-20262/back-end/tree/andres/meeting-proposal-retry) ship together. The audit fixes require no new database migration. Production still relies on the existing two-sided exchange confirmation migration.
