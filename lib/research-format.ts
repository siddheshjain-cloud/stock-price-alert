export function fmtPct(value: string | null | undefined) {
  if (value === null || value === undefined) return '—';
  return `${Number(value).toFixed(2)}%`;
}

export function fmtNum(value: string | null | undefined, unit?: string | null) {
  if (value === null || value === undefined) return '—';
  const num = Number(value);
  const formatted = Number.isFinite(num) ? num.toLocaleString('en-IN') : value;
  return unit ? `${formatted} ${unit}` : formatted;
}

export function fmtDate(value: string | null | undefined) {
  if (!value) return '—';
  try {
    return new Date(value).toLocaleDateString('en-IN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  } catch {
    return value;
  }
}
