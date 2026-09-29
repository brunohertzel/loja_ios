# API Mobile usada pelo aplicativo

Base: `/api/mobile/v1`

## Fundação já existente
- `GET /bootstrap.php`
- `GET /health.php`
- `POST /auth/login.php`
- `POST /auth/refresh.php`
- `POST /auth/logout.php`
- `GET /auth/me.php`
- `POST /security/biometric.php`
- `POST /metrics/event.php`

## Loja / catálogo esperada pela V1.2.0
- `GET /store/home.php`
- `GET /store/categories.php`
- `GET /store/products.php`
- `GET /store/product.php`

A camada de catálogo deve ser implementada no backend reutilizando preço, disponibilidade, campanhas e regras da loja web.
