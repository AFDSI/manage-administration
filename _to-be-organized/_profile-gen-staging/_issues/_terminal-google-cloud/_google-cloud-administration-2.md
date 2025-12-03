
Please improve this summary

## process

0. Prerequisites:

Get Google Cloud SDK for WSL/Linux

```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

1. Authenticate

```bash
gcloud auth login
# This will open a browser for you to sign in
```

2. Run commands, e.g. list projects:

- `gcloud projects list`

3. Expected Output:

```
PROJECT_ID              NAME                    PROJECT_NUMBER
my-project-id           My Project Name         123456789012
another-project         Another Project         987654321098
```

4. List Buckets for Each Project

- `gcloud storage buckets list --project="[PROJECT_ID]"`

5. View contents to see if they contain webpage files

- `gcloud storage ls gs://[BUCKET_NAME]/`


## questions

- How to set account identity for each new session after initial web browser login?
- How are commands classified?
- By category, how to get a list of Google Cloud commands?
