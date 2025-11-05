# Base Templates

This directory contains shared templates and configurations used across all services.

## Usage

Service charts can reference base templates using:

```yaml
{{- include "base.commonLabels" . }}
{{- include "base.commonAnnotations" . }}
```

## Structure

- `_helpers.tpl`: Common helper templates for labels, annotations, and other shared logic











