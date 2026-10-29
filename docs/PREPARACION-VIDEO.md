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

## 3. Dejar abiertas las pestañas para grabar

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
