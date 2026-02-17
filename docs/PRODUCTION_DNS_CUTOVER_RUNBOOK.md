# Production DNS Cutover Runbook (Namecheap + Render)

Last updated: 2026-02-15

## Purpose
Move `sqlbook.com` traffic from the current legacy host to Render production with minimal risk, no SSL surprises, and no staging/production crossover.

## Scope
- Domain registrar/DNS: Namecheap
- Hosting target: Render production web service
- Must not change staging: `staging.sqlbook.com`

## Preconditions (must be true before cutover)
- Production Render services exist and are healthy on Render default URL:
  - Web
  - Worker
  - Postgres
  - Redis
- Production env vars are set correctly (`APP_HOST=sqlbook.com`, `APP_PROTOCOL=https`).
- `/up` is healthy on the Render production default URL.
- Production email/auth flow has been smoke-tested on the default Render URL.

## Recommended timing
- Run cutover during a low-traffic window.
- Avoid making other infra changes at the same time.

## Step-by-step cutover
1. In Render production web service, add custom domains:
   - `sqlbook.com`
   - `www.sqlbook.com`
2. In Namecheap, reduce TTL on current root/`www` records to `300` (or lowest allowed), wait for old TTL window to pass.
3. Replace DNS records exactly as Render requests for each domain.
4. Keep `staging` CNAME unchanged:
   - `staging -> sqlbook-staging-web.onrender.com`
5. Wait for Render certificate status to become issued/active for both production domains.
6. Verify:
   - `https://sqlbook.com/up`
   - `https://www.sqlbook.com/up`
   - Home page and app routes load normally
   - Login/signup emails contain `sqlbook.com` links
7. After successful verification, remove obsolete legacy root records pointing to old infrastructure.

## Validation checklist
- [ ] `sqlbook.com` resolves to Render target
- [ ] `www.sqlbook.com` resolves to Render target
- [ ] TLS valid on both domains
- [ ] No redirects to old host
- [ ] No redirects to staging host
- [ ] Auth links use production domain
- [ ] Worker and events pipeline healthy

## Rollback plan
If critical issues appear:
1. Revert Namecheap root/`www` records to previous known-good values.
2. Confirm site recovers on previous host.
3. Fix production Render issue.
4. Retry cutover in next maintenance window.

## Notes
- Keep staging isolated from production at all times.
- Do not delete staging DNS during production cutover.
