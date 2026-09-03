# Gerar APK online (sem instalar Flutter)

Escolha **uma** das opções abaixo.

---

## Opção A — GitHub Actions (grátis, recomendado)

### 1. Criar repositório no GitHub
1. Acesse https://github.com/new  
2. Nome: `assistify` (ou outro)  
3. Pode ser **privado**  
4. Criar repositório **vazio** (sem README)

### 2. Enviar o projeto
No computador, extraia o ZIP e rode:

```bash
cd assistify_flutter
git init
git add .
git commit -m "Assistify IPTV"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/assistify.git
git push -u origin main
```

(Substitua `SEU_USUARIO` pelo seu usuário do GitHub.)

Se não tiver Git, use o site do GitHub: **Add file → Upload files** e envie toda a pasta.

### 3. Rodar o build
1. No GitHub, abra o repositório  
2. Aba **Actions**  
3. Clique em **Build Assistify APK**  
4. **Run workflow** → **Run workflow**  
5. Espere 5–10 minutos  
6. Quando ficar verde, abra o job → **Artifacts** → baixe **assistify-apk**  
7. Dentro do ZIP está o `app-release.apk`

---

## Opção B — Codemagic (grátis com limite)

1. Acesse https://codemagic.io e entre com GitHub  
2. Clique em **Add application** → escolha o repositório `assistify`  
3. Em Workflow, selecione o arquivo `codemagic.yaml`  
4. Start new build  
5. Ao terminar, baixe o APK em **Artifacts**

---

## Depois de instalar

Login:
- **Servidor:** `http://telaplay.lat` (só a base, sem get.php)
- **Usuário** e **Senha** do painel

Desinstale qualquer Assistify antigo antes de instalar o APK novo.
