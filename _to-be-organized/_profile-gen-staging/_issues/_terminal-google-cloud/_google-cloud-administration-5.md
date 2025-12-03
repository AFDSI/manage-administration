While Google Cloud has a powerful command-line interface (CLI) that covers the vast majority of services, some features can only be set or fully administered through the web console.

This is not a fixed list, as Google is constantly adding `gcloud` support for more services. However, the features that are often console-exclusive fall into a few general categories.

***

### Features Often Limited to the Web Console

#### 1. Highly Visual & Interactive Tools

Some tools are inherently graphical and don't have a direct CLI equivalent because their main purpose is visualization and interaction.

* **Dashboards and Monitoring:** While you can retrieve monitoring data (metrics) via the CLI, **creating and arranging custom dashboards** in Cloud Monitoring is a visual, drag-and-drop process done exclusively in the console.
* **Cloud Scheduler Job "Run Now":** The "Force run" button in the console, which triggers a scheduled job immediately, does not have a direct `gcloud scheduler jobs run` equivalent. This is a purely console-based action.
* **Security Command Center:** Viewing and interacting with the graphical risk dashboards, threat visualizations, and asset inventory graphs is a console-only experience.
* **IAM Policy Troubleshooter:** This is an interactive tool for diagnosing "access denied" errors. You input a principal, resource, and permission, and it visually traces the policy hierarchy. This workflow is designed for and executed within the web console.


#### 2. Initial Service Setup & Configuration

For some services, the initial enablement and high-level configuration must be performed in the console before the CLI can be used for routine administration.

* **Enabling APIs:** While you can enable APIs with `gcloud services enable`, the initial browsing, discovery, and management of APIs in the "APIs & Services" library, including viewing detailed analytics and quotas, is much richer and more intuitive in the console.
* **Marketplace Deployments:** Deploying third-party solutions from the Google Cloud Marketplace is a wizard-driven process that is handled through the web interface.

#### 3. Newer or Niche Services

Services that are in **Alpha** or early **Beta** stages often have limited or no `gcloud` support. The web console is typically the first interface available for these new features. By the time a service becomes Generally Available (GA), it usually has robust CLI support.

### The Inverse: What Cannot Be Done in the CLI?

Based on the points above, you **cannot** easily use the CLI for tasks like:

* **Visually designing** a monitoring dashboard.
* **Interactively debugging** an IAM policy issue with a graphical troubleshooter.
* **Deploying complex applications** from the Cloud Marketplace with a single command.
* **Forcing an immediate run** of a Cloud Scheduler job.

**The general rule is:** If the task is primarily about visual interaction, graphical representation of data, or a guided, step-by-step setup wizard, you'll likely need to use the Google Cloud web console. For nearly all other resource management and automation (creating VMs, deploying code, managing buckets), the CLI is not only capable but often more efficient.
