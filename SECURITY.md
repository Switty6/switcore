# Securitate

## Raportare

Pentru vulnerabilități, **nu deschide un issue public**. Folosește [Private Security Advisory](https://github.com/Switty6/switcore/security/advisories/new).

Include în raport:
- Descriere și impact
- Pași pentru reproducere
- Eventual o sugestie de fix

Răspuns în maxim 72h. Vei fi creditat la publicarea fix-ului (sau anonim, la cerere).

## Scope

**În scope:** module sub `[switcore]/`, auth la `settings-panel`, SQL injection, RCE prin evenimente FiveM, dupe-uri de bani/items, escaladare de permisiuni, bypass de ownership.

**În afara scope-ului:** dependențe terțe (raportează upstream), exploits de client FiveM nelegate de framework, DoS prin spam de evenimente (rate-limit e treaba operatorului), probleme care necesită deja acces la server sau DB.

## Versiuni suportate

Doar ultima versiune de pe `main`. Fix-urile se publică ca release nou.

## Hardening pentru operatori

- Credențiale (DB, JWT, parolă admin) în convars `server.cfg`, **nu** în fișiere committed.
- JWT secret minim 32 caractere random (`openssl rand -hex 48`).
- `switcore_panel_cors_origins` fără `*` în producție.
- PostgreSQL doar pe `localhost` sau VPN, nu expus public.
- Update regulat.
