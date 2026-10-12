// Mirrors app/schemas/admin_alerts.py (backendtest) exactly.

export interface AlertEvent {
  id: string;
  event_type: string;
  source_table: string;
  source_id: string;
  company_id: string | null;
  severity: 'INFO' | 'WATCH' | 'CRITICAL';
  summary: string;
  details: Record<string, unknown> | null;
  occurred_at: string;
}

export interface AlertEventList {
  items: AlertEvent[];
}
