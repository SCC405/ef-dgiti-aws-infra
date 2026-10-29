# Preparación antes de grabar (cada integrante, en SU cuenta)

El profesor exige que **cada uno** muestre su propia cuenta de AWS Academy y que haga
la demostración él mismo. Por eso la infraestructura se despliega en las tres cuentas
con el mismo código de Terraform. Son 3 pasos y unos 20 minutos de espera.

## 1. Abrir el laboratorio (2 min)

1. Entrar a https://awsacademy.instructure.com → curso **AWS Academy Learner Lab** →
   **Módulos** → **Iniciar el Laboratorio de aprendizaje de AWS Academy**.
2. Clic en **▶ Start Lab** y esperar a que el punto junto a "AWS" se ponga **verde** (1–3 min).
3. Clic en **AWS** (el punto verde): se abre la consola de AWS en otra pestaña.

> Ojo: **no** usar la terminal negra de la página del laboratorio para Terraform: esa
> terminal usa otra cuenta. Todo se hace desde **CloudShell**, dentro de la consola.

## 2. Desplegar con Terraform desde CloudShell (20 min, casi todo espera)

1. En la consola de AWS, arriba a la derecha, el icono `>_` (**CloudShell**).
   Cerrar la ventana de bienvenida.
2. Pegar esta línea y Enter (instala Terraform y descarga el repositorio):

   ```bash
   curl -sL https://raw.githubusercontent.com/SCC405/ef-dgiti-aws-infra/main/scripts/lab-setup.sh | bash
   ```

   Debe terminar mostrando `arn:aws:sts::<SU número de cuenta>:assumed-role/voclabs/...`.
3. Pegar y Enter:

   ```bash
   source ~/.bashrc && cd ~/ef-dgiti-aws-infra/infra && terraform init && terraform plan -out=tfplan && terraform apply tfplan
   ```

   Al final debe decir **`Apply complete! Resources: 48 added`** y mostrar los outputs
   (`app_url`, `swagger_url`, `cloudwatch_dashboard_url`, ...).
4. Esperar **5 minutos más** a que las EC2 instalen Docker y arranquen la app. Abrir el
   `health_url` en el navegador: debe responder `{"status":"ok", ...}`.

> CloudShell se cierra si pasan ~20 minutos sin tocar el teclado. Si se cierra durante
> el apply, abrirlo de nuevo y repetir el paso 3: Terraform continúa donde quedó.

## 3. Tareas extra según la parte de cada uno

### Santiago: secretos de GitHub para que el job de despliegue corra (5 min)

El job "4 - Despliegue" (lo muestra Erick) se conecta a AWS con credenciales guardadas
como secretos de GitHub. Las pone Santiago, que es el dueño del repo, con las de su
cuenta (donde ya está todo desplegado). Caducan cada vez que se reinicia el
laboratorio, así que se hace el mismo día de grabar, con el lab en verde:

1. En la página del laboratorio: **ⓘ AWS Details** → junto a "AWS CLI" clic en **Show**.
2. En GitHub: https://github.com/SCC405/ef-dgiti-aws-infra/settings/environments →
   **aws-academy** → **Add environment secret**, tres veces:
   - `AWS_ACCESS_KEY_ID` = el valor de `aws_access_key_id`
   - `AWS_SECRET_ACCESS_KEY` = el valor de `aws_secret_access_key`
   - `AWS_SESSION_TOKEN` = el valor de `aws_session_token` (es largo, copiarlo completo)
3. GitHub → **Actions** → **CI-CD** → **Run workflow**. Tarda unos 10 minutos
   (el instance refresh cambia las instancias de a una). Debe quedar todo en verde.

> Los valores no se ven después de guardarlos: GitHub los muestra como `***`.

### Nicolay: correr las pruebas de carga antes de grabar (20 min)

Para que su dashboard de CloudWatch tenga las gráficas del guion, en PowerShell
(desde la carpeta del repo clonado) y con la URL de **su** balanceador:

```powershell
k6 run -e BASE_URL=http://<su alb_dns_name> load-tests/k6-load.js
```

Esperar 5 minutos (el Auto Scaling sube de 2 a 4 y las nuevas quedan sanas) y correrla
otra vez. Guardar los dos resúmenes que imprime k6: son los números de su parte.

## 4. Dejar abiertas las pestañas para grabar

Cada uno, en el orden de su parte del guion (`docs/GUION.md`):

| Integrante | Pestañas |
|---|---|
| **Santiago** | Diagrama (`docs/arquitectura.png`), repo en GitHub (carpeta `infra/`), CloudShell |
| **Erick** | AWS Academy con el lab en verde, `app_url/status`, `app_url/docs` (Swagger), PowerShell, GitHub → Actions |
| **Nicolay** | AWS Academy con el lab en verde, PowerShell con k6 listo, CloudWatch → Dashboards → `ef-dgiti-dashboard`, EC2 → Target groups → `ef-dgiti-tg`, EC2 → Auto Scaling groups → `ef-dgiti-asg` |

## Después de grabar: borrar todo (cada uno en su CloudShell)

```bash
cd ~/ef-dgiti-aws-infra/infra && terraform destroy -auto-approve
```

Así no se gasta el crédito del laboratorio (el NAT Gateway y las dos RDS cobran por hora).
