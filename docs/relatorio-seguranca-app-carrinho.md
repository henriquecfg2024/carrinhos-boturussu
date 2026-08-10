# Relatório de Segurança — app-carrinho

**Data da análise:** 10/08/2026  
**Escopo analisado:** `B:\\henrique-dev\\app-carrinho\\Boturussu` e schema Supabase `rwspmfowmodcervlbyfq`  
**Tipo:** análise estática, defensiva e não destrutiva

## 1. Resumo Executivo

O projeto analisado é um frontend estático composto principalmente por `index.html`, Service Worker e integração Supabase. O schema de produção confirmado pelo SQL Editor possui `agendamentos`, `app_store`, `locais`, `logs` e `waitlist`.

Foram identificados riscos críticos de controle de acesso e autenticação. O aplicativo mantém 35 usuários, 101 agendamentos e 515 logs em `app_store`, cuja policy de produção é `public + ALL + using true`. Além disso, a autenticação legada e a autorização eram feitas no navegador, as senhas eram apenas codificadas em Base64 e existiam contas administrativas com credenciais padrão no código.

A correção deve ser gradual: migrar cada usuário no primeiro login, preservar IDs legados e só então aplicar a barreira de policies autenticadas. Não deve haver recadastro em massa nem exclusão imediata de `app_store.users`.

## 2. Arquitetura e Tecnologias Identificadas

- Frontend: HTML, CSS e JavaScript embutidos em `index.html`.
- Distribuição: aplicação estática/PWA.
- Persistência local: `localStorage`.
- Persistência remota: Supabase, por meio da tabela `public.app_store`.
- Cliente Supabase: carregado de CDN em `index.html:24` e `index (1).html:21`.
- Banco: migrations em `supabase/migrations/` e backups SQL em `backups/`.
- Offline: Service Worker em `sw.js` e `sw (1).js`.
- Integrações externas: Nominatim, Open-Meteo, Google Fonts, jsDelivr e WhatsApp.
- Não identificados: backend próprio, `package.json`, lockfiles, Dockerfile ou workflows de CI/CD.
- Schema Supabase confirmado: `agendamentos`, `app_store`, `locais`, `logs` e `waitlist`.
- Produção confirmou policies `public` com comando `ALL` e condição `true` nas cinco tabelas.

## 3. Tabela de Vulnerabilidades

| ID | Título | Severidade | Status | Confiança | Arquivo |
|---|---|---:|---|---:|---|
| ID-001 | Escrita e leitura públicas de todo o estado da aplicação | Crítica | Confirmado | Alta | `backups/schema_atual.md:18-19`, `index.html:2416,2430` |
| ID-002 | Autenticação e autorização implementadas somente no cliente | Crítica | Confirmado | Alta | `index.html:2763-2799` |
| ID-003 | Credenciais administrativas padrão e redefinição previsível | Crítica | Confirmado | Alta | `index.html:2524,2543,3963-3971` |
| ID-004 | Exposição e armazenamento inseguro de dados pessoais e credenciais | Alta | Confirmado | Alta | `index.html:2406-2437`, `backups/schema_atual.md:22-27` |
| ID-005 | Possível XSS por interpolação de dados em `innerHTML` | Alta | Possível | Média | `index.html:3828,5118-5132,5439-5450,5563-5570` |
| ID-006 | Políticas RLS permitem escrita pública em tabelas administrativas | Alta | Confirmado | Alta | `supabase/migrations/01-04*.sql` |
| ID-007 | Dependência JavaScript carregada sem versão fixada | Média | Confirmado | Alta | `index.html:24`, `index (1).html:21` |
| ID-008 | Função `SECURITY DEFINER` sem endurecimento explícito | Média | Possível | Média | `supabase/migrations/06_function_get_effective_support_point.sql:2-43` |
| ID-009 | Envio de localização precisa para serviços externos | Média | Confirmado | Alta | `index.html:2858-2864` |
| ID-010 | Backup SQL com dados persistidos da aplicação no repositório | Alta | Possível | Média | `backups/supabase_backup_05_08_2026.sql:24` |

## 4. Vulnerabilidades Confirmadas

### [ID-001] Escrita e leitura públicas de todo o estado da aplicação

- **Severidade:** Crítica
- **OWASP/CWE:** A01:2021 — Broken Access Control / CWE-862
- **Confiança:** Alta
- **Status:** Confirmado
- **Local:** `backups/schema_atual.md:18-19`; `index.html:2416,2430`
- **Componente:** Supabase `app_store` e camada de persistência do frontend
- **Descrição técnica:** A tabela `app_store` possui política de leitura para todos e política `FOR ALL USING (true)`. O frontend lê todo o conteúdo da tabela e realiza `upsert` sem uma autorização de servidor por usuário ou função.
- **Evidência:** As políticas permitem leitura e escrita públicas; o cliente chama `select('*')` e `upsert(...)` diretamente.
- **Cenário de abuso:** Qualquer cliente com acesso ao aplicativo pode consultar ou sobrescrever chaves que representam usuários, perfis, agendamentos, logs e configurações.
- **Impacto:** Comprometimento integral da confidencialidade e integridade dos dados, criação de administradores, alteração de agendamentos e perda de disponibilidade.
- **Correção:** Remover o modelo chave-valor público. Criar tabelas normalizadas, usar Supabase Auth e políticas RLS com `auth.uid()`. Permitir escrita administrativa somente por role validada no servidor.
- **Código seguro:** A autorização deve ocorrer nas policies e no banco; não confiar em `currentUser.perfil` no JavaScript.
- **Teste de validação:** Com um usuário comum, confirmar que não é possível ler ou modificar dados de outro usuário nem tabelas administrativas.

### [ID-002] Autenticação e autorização implementadas somente no cliente

- **Severidade:** Crítica
- **OWASP/CWE:** A07:2021 — Identification and Authentication Failures / CWE-602
- **Confiança:** Alta
- **Status:** Confirmado
- **Local:** `index.html:2474,2763-2778,2790-2799,3640-3645`
- **Componente:** Login, sessão e painel administrativo
- **Descrição técnica:** O login compara dados carregados no navegador. O acesso ao painel é controlado por uma variável JavaScript (`currentUser`) e pelo campo `perfil` armazenado no cliente.
- **Evidência:** `encPwd` usa Base64; `login` procura usuários em `localStorage`; `showScreen` e `initAdminScreen` verificam o perfil somente no cliente.
- **Cenário de abuso:** Um usuário pode manipular o estado local ou as respostas/dados sincronizados para se apresentar como administrador. A política pública de escrita agrava o problema.
- **Impacto:** Acesso administrativo, alteração de dados e impersonação de usuários.
- **Correção:** Usar Supabase Auth para identidade e sessão. Validar autorização no banco/API com RLS, claims e funções seguras. Nunca usar Base64 como proteção de senha.
- **Código seguro:** Armazenar somente o identificador do usuário autenticado e validar `auth.uid()` no banco.
- **Teste de validação:** Tentar acessar cada operação administrativa com um usuário comum e verificar a rejeição no servidor, não apenas a ocultação da tela.

### [ID-003] Credenciais administrativas padrão e redefinição previsível

- **Severidade:** Crítica
- **OWASP/CWE:** A07:2021 / CWE-798
- **Confiança:** Alta
- **Status:** Confirmado
- **Local:** `index.html:2524,2543,3963-3971`
- **Componente:** Seed do frontend e gerenciamento de usuários
- **Descrição técnica:** O código cria contas administrativas com senha padrão e redefine senhas de usuários para um valor fixo conhecido, exibindo esse valor na interface.
- **Evidência:** O código contém contas `master` inicializadas com senha padrão e a função `resetPassword` grava a senha fixa `123456`.
- **Cenário de abuso:** Qualquer pessoa que conheça o código ou observe o aplicativo pode tentar a credencial padrão e obter acesso administrativo.
- **Impacto:** Comprometimento total da aplicação e dos dados.
- **Correção:** Remover credenciais padrão do código, invalidar imediatamente essas contas e usar convite, recuperação segura e senha aleatória temporária com expiração.
- **Código seguro:** Delegar criação, recuperação e alteração de senha ao Supabase Auth.
- **Teste de validação:** Confirmar que nenhum segredo ou senha padrão permanece no código, histórico, backups ou dados ativos.

### [ID-004] Exposição e armazenamento inseguro de dados pessoais e credenciais

- **Severidade:** Alta
- **OWASP/CWE:** A02:2021 — Cryptographic Failures / CWE-922
- **Confiança:** Alta
- **Status:** Confirmado
- **Local:** `index.html:2406-2437,4307-4310`; `backups/schema_atual.md:22-27`
- **Componente:** `localStorage`, `app_store` e exportação de backup
- **Descrição técnica:** Usuários, telefones, perfis, senhas codificadas, agendamentos e logs são armazenados no navegador e sincronizados como JSONB. O aplicativo também exporta conjuntos de dados para arquivo JSON.
- **Evidência:** A camada `load/save` usa `localStorage`; a sincronização lê todos os registros; a exportação inclui usuários, agendamentos e logs.
- **Cenário de abuso:** Qualquer script executado na origem, extensão maliciosa ou pessoa com acesso ao dispositivo pode ler os dados locais. A tabela pública também permite acesso remoto indevido.
- **Impacto:** Vazamento de PII, telefones, histórico de atividades, perfis e material de autenticação.
- **Correção:** Remover credenciais do JSONB, usar Auth, minimizar dados, restringir RLS, criptografar backups e impedir exportações indiscriminadas.
- **Código seguro:** Exportar somente dados autorizados e sem credenciais, mediante autorização no backend.
- **Teste de validação:** Verificar que usuários comuns só acessam seus próprios dados e que nenhum backup contém senhas ou tokens.

### [ID-006] Políticas RLS permitem escrita pública em tabelas administrativas

- **Severidade:** Alta
- **OWASP/CWE:** A01:2021 / CWE-862
- **Confiança:** Alta
- **Status:** Confirmado
- **Local:** `supabase/migrations/01_create_support_points.sql:18-22`; `02_create_service_locations.sql:14-18`; `03_create_equipments.sql:13-17`; `04_create_responsibilities.sql:13-17`
- **Componente:** Supabase
- **Descrição técnica:** As tabelas habilitam RLS, mas as policies de escrita usam `FOR ALL USING (true)`, sem verificar identidade ou função administrativa.
- **Cenário de abuso:** Um cliente anônimo pode modificar pontos de apoio, locais, equipamentos e responsabilidades.
- **Impacto:** Fraude operacional, alteração de endereços e telefones, redirecionamento de usuários e corrupção de dados.
- **Correção:** Separar policies de `SELECT`, `INSERT`, `UPDATE` e `DELETE`; usar `auth.uid()` e uma tabela segura de roles; adicionar `WITH CHECK` restritivo.
- **Teste de validação:** Verificar operações de leitura e escrita com sessões de visitante, usuário comum e administrador.

### [ID-007] Dependência JavaScript carregada sem versão fixada

- **Severidade:** Média
- **OWASP/CWE:** CWE-829 — Inclusion of Functionality from Untrusted Control Sphere
- **Confiança:** Alta
- **Status:** Confirmado
- **Local:** `index.html:24`; `index (1).html:21`
- **Componente:** Carregamento do cliente Supabase
- **Descrição técnica:** O pacote `@supabase/supabase-js@2` é carregado dinamicamente de CDN sem versão exata e sem Subresource Integrity.
- **Impacto:** Alteração inesperada do artefato, indisponibilidade ou risco de supply chain.
- **Correção:** Fixar a versão, usar dependência empacotada localmente e aplicar SRI quando CDN for indispensável.
- **Teste de validação:** Confirmar que o hash/versão do artefato é controlado no processo de build e implantação.

### [ID-008] Função `SECURITY DEFINER` sem endurecimento explícito

- **Severidade:** Média
- **OWASP/CWE:** CWE-732 / CWE-250
- **Confiança:** Média
- **Status:** Possível
- **Local:** `supabase/migrations/06_function_get_effective_support_point.sql:2-43`
- **Componente:** Função PostgreSQL
- **Descrição técnica:** A função é criada com `SECURITY DEFINER`, mas não define explicitamente `search_path` nem trata privilégios de execução.
- **Impacto:** Aumenta o risco de execução com contexto privilegiado caso o ambiente, objetos ou privilégios sejam alterados futuramente.
- **Correção:** Definir `SET search_path = pg_catalog, public` ou usar referências totalmente qualificadas, revogar `EXECUTE` público quando não necessário e concedê-lo somente a roles apropriadas.
- **Teste de validação:** Auditar privilégios efetivos da função e executar testes com roles não administrativas.

### [ID-009] Envio de localização precisa para serviços externos

- **Severidade:** Média
- **OWASP/CWE:** CWE-359 — Exposure of Private Personal Information
- **Confiança:** Alta
- **Status:** Confirmado
- **Local:** `index.html:2858-2864`
- **Componente:** Geolocalização e previsão do tempo
- **Descrição técnica:** Coordenadas precisas do dispositivo são enviadas a Nominatim e Open-Meteo.
- **Impacto:** Divulgação de localização potencialmente sensível a terceiros, sem evidência de consentimento granular, minimização ou política de retenção.
- **Correção:** Solicitar consentimento explícito, reduzir precisão quando possível, documentar terceiros e oferecer alternativa sem geolocalização.
- **Teste de validação:** Verificar consentimento, política de privacidade e comportamento quando a permissão é negada.

## 5. Possíveis Vulnerabilidades

### [ID-005] Possível XSS por interpolação de dados em `innerHTML`

- **Severidade:** Alta
- **OWASP/CWE:** A03:2021 — Injection / CWE-79
- **Confiança:** Média
- **Status:** Possível
- **Local:** `index.html:3828,5118-5132,5439-5450,5563-5570`
- **Componente:** Renderização de usuários, pontos de apoio, locais e responsabilidades
- **Descrição técnica:** Valores de usuários e dados administrativos são interpolados em HTML por meio de `innerHTML`, incluindo nomes, endereços, descrições, URLs e telefones.
- **Evidência:** Há múltiplas construções de templates HTML com dados carregados do estado persistido.
- **Limitação:** A explorabilidade exata depende de quais campos podem ser controlados por usuários e de como o conteúdo chega ao banco. A escrita pública identificada em ID-001 e ID-006 aumenta significativamente essa possibilidade.
- **Correção:** Usar `textContent`, criação segura de nós DOM, sanitização com biblioteca confiável e validação de URLs por allowlist.

### [ID-010] Backup SQL com dados persistidos da aplicação no repositório

- **Severidade:** Alta
- **OWASP/CWE:** A02:2021 / CWE-530
- **Confiança:** Média
- **Status:** Possível
- **Local:** `backups/supabase_backup_05_08_2026.sql:24`
- **Componente:** Backup e controle de versão
- **Descrição técnica:** O backup contém uma instrução de inserção de dados da tabela `app_store`, que, segundo o schema documentado, armazena usuários, perfis, agendamentos e relatórios.
- **Limitação:** O conteúdo dos dados não foi exibido para evitar exposição de informações sensíveis.
- **Correção:** Remover dados reais de backups versionados, aplicar segredo/PII scanning, criptografar backups e armazená-los em repositório protegido com retenção controlada.

## 6. Top 5 Arquivos Mais Críticos

1. `index.html` — contém a aplicação, autenticação, credenciais padrão e camada de persistência.
2. `backups/schema_atual.md` — documenta policies públicas sobre dados de usuários.
3. `supabase/migrations/01_create_support_points.sql` — permite escrita pública em dados administrativos.
4. `supabase/migrations/02_create_service_locations.sql` — permite escrita pública em locais.
5. `backups/supabase_backup_05_08_2026.sql` — contém dados persistidos da aplicação.

## 7. Possíveis Segredos Expostos, Sempre Mascarados

- `index.html:2403` e `index (1).html:1194`: chave pública `anon` do Supabase embutida no frontend.
- `index.html:2524,2543`: credenciais administrativas padrão codificadas no código.
- `index.html:3966-3971`: senha fixa usada na redefinição administrativa.

A chave `anon` não deve ser tratada como segredo equivalente a `service_role`, mas sua exposição só é aceitável quando as policies RLS forem rigorosas. Neste projeto, as policies públicas tornam a combinação de chave pública e banco permissivo crítica.

## 8. Análise de Dependências

- Não foram encontrados `package.json`, lockfiles ou `requirements.txt` no diretório analisado.
- A biblioteca Supabase é carregada diretamente de jsDelivr sem versão exata.
- Não foi executada instalação, atualização ou auditoria externa de dependências.
- Não foi possível confirmar vulnerabilidades específicas de versões além do risco de dependência não fixada.

## 9. Falhas de Autenticação e Autorização

- Autenticação local no navegador.
- Senhas codificadas em Base64, sem hashing criptográfico adequado.
- Perfis administrativos confiados a dados controlados pelo cliente.
- Contas administrativas padrão no código.
- RLS pública para leitura e escrita.
- Ausência de evidência de Supabase Auth ou de autorização server-side.

## 10. Riscos Específicos de Carrinho, Preços e Pagamentos

O projeto analisado aparenta ser uma agenda de carrinhos de publicações, e não um e-commerce tradicional com pagamento. Ainda assim, os fluxos de agendamento, check-in, fila, locais e responsabilidades podem ser manipulados porque o estado é armazenado no cliente e pode ser alterado por qualquer cliente autorizado pela policy pública.

Riscos observados:

- Agendamentos e filas podem ser alterados ou removidos indevidamente.
- Dados de capacidade e disponibilidade não têm enforcement confiável no servidor.
- Check-in e check-out são controlados pelo JavaScript.
- Dados de contato e locais podem ser substituídos por conteúdo malicioso.

## 11. Falhas de Docker, CI/CD e Configuração de Produção

- Não foram encontrados Dockerfiles ou workflows de CI/CD.
- Não foi possível verificar headers HTTP de produção por a análise ser estática.
- Recomenda-se configurar CSP, HSTS, `Referrer-Policy`, `Permissions-Policy`, `X-Content-Type-Options` e proteção adequada de origem.
- Recomenda-se remover scripts inline ou adotar CSP com nonce/hash controlado.

## 12. Checklist de Correção Prioritária

- [ ] Revogar e substituir credenciais administrativas padrão.
- [ ] Migrar autenticação para Supabase Auth.
- [ ] Remover senhas e perfis do `localStorage` e do JSONB público.
- [ ] Remover policies `FOR ALL USING (true)`.
- [ ] Criar policies RLS baseadas em `auth.uid()` e roles seguras.
- [ ] Normalizar `app_store` em tabelas com autorização por registro.
- [ ] Impor autorização no banco/API, não apenas no frontend.
- [ ] Remover dados reais dos backups versionados.
- [ ] Corrigir renderizações com `innerHTML` e sanitizar URLs.
- [ ] Fixar a versão do Supabase JS e usar SRI ou empacotamento local.
- [ ] Endurecer a função `SECURITY DEFINER` e seus privilégios.
- [ ] Revisar consentimento e minimização de dados de geolocalização.
- [ ] Adicionar testes automatizados de RLS, autenticação e autorização.

## 13. Testes de Segurança Recomendados

1. Testes de RLS com visitante, usuário comum, administrador e master.
2. Testes de acesso horizontal entre usuários.
3. Testes de acesso vertical entre publicador, administrador e master.
4. Testes de alteração de preços, capacidade, filas e agendamentos no servidor.
5. Testes de XSS em nomes, endereços, descrições, URLs e mensagens.
6. Testes de recuperação, expiração e invalidação de sessão.
7. Scan de segredos no histórico e nos backups.
8. Scan de dependências após a criação de lockfiles e manifesto de build.
9. Verificação de headers HTTP e CSP no ambiente publicado.
10. Testes de privacidade para geolocalização e integrações externas.

## 14. Limitações da Análise

- A auditoria foi estática e não executou a aplicação.
- Não foram feitas requisições ao Supabase ou a outros serviços externos.
- Não foram testadas policies no ambiente remoto.
- O conteúdo de arquivos sensíveis e dados de backup não foi exibido.
- Não foram encontrados manifesto de dependências, backend próprio, Dockerfile ou CI/CD no escopo.
- A raiz do workspace contém o subdiretório `Boturussu`; ele foi tratado como o projeto efetivo.

## 15. Nota de Risco Geral

**Crítico**

A combinação de autenticação somente no cliente, credenciais padrão, dados sensíveis no navegador e policies Supabase com leitura e escrita públicas permite comprometimento amplo da aplicação. O sistema não deve ser considerado adequado para dados reais até que autenticação, autorização, RLS e armazenamento de credenciais sejam redesenhados.

## 16. Remediação Implementada

- Adicionada `supabase/migrations/08_auth_hardening.sql`.
- Adicionada a Edge Function `supabase/functions/legacy-login/index.ts` para migração transparente no primeiro login.
- Criada a tabela `public.profiles` vinculada a `auth.users`.
- Adicionadas policies RLS para perfil próprio e administradores.
- Adicionada função/trigger seguro para criar perfil após cadastro no Auth.
- Removidas as policies legadas de leitura/escrita irrestritas de `app_store`.
- Escrita remota do cache legado restrita a administradores.
- Removidas contas padrão, senha fixa e Base64 do frontend principal; as credenciais legadas permanecem somente como fonte temporária server-side.
- Login, cadastro, sessão e troca de senha passaram a usar Supabase Auth.
- Arquivo `index (1).html` foi marcado como legado e redireciona para `index.html`.

### Pendências para implantação

- Aplicar a migration 08 no projeto Supabase.
- Implantar a Edge Function `legacy-login` com `SUPABASE_SERVICE_ROLE_KEY`; os colaboradores poderão entrar uma vez com o telefone e senha atuais, sem recadastro.
- Não apagar a chave legada `users` até concluir a migração; após a primeira autenticação de todos, removê-la em uma migration posterior.
- Configurar o fluxo de confirmação/recuperação do Supabase Auth com um endereço real ou provedor de SMS/e-mail.
- Rotacionar e remover do controle de versão o backup SQL que contém dados antigos.
- Migrar agendamentos, filas e relatórios para tabelas com `user_id` e policies por registro; enquanto isso, usuários comuns usam cache local para operações de escrita.

## Referências

- OWASP Top 10.
- OWASP API Security Top 10.
- CWE Top 25.
- Princípio do menor privilégio.
- Supabase Auth e Row Level Security.
