# Category monthly threshold — design decision

Issue #13 uses **Option A: a nullable `monthly_threshold` column on `categories`**.

The threshold is a category property, is easy to query with the existing category load path, and automatically participates in the current local cache and category SyncQueue payload because `Category.toJson` / `fromJson` are the shared serialization boundary.

A dedicated table is intentionally deferred until the product needs threshold history, multiple periods, or multiple threshold types. The calculator remains independent from persistence so Financial Insights and Forecast can reuse it later.

## Offline behavior

Category updates remain optimistic through `CategoriesStore`, are persisted to the existing local category cache, and are queued as the existing `categories` sync operation. A restart therefore retains the pending threshold change and reconnection reuses the existing sync handler.
