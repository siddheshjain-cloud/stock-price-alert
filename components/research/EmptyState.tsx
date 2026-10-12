import { FileQuestion, Lock } from 'lucide-react';

/**
 * Two deliberately different looks for two different real states --
 * never collapsed into one generic "nothing here" message:
 *  - `locked`: the viewer's tier does not include this section at all.
 *    The data may well exist; it is withheld, not missing.
 *  - default: the viewer is entitled, and the backend genuinely has no
 *    current record for this section yet.
 */
export function EmptyState({
  title,
  locked = false,
  requiredTier,
}: {
  title: string;
  locked?: boolean;
  requiredTier?: string;
}) {
  if (locked) {
    return (
      <div className="flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed py-12 text-center text-muted-foreground">
        <Lock className="size-6" />
        <p className="text-sm font-medium">{title}</p>
        <p className="text-xs">
          Available on {requiredTier ?? 'Premium'}. Not shown for your current access level.
        </p>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed py-12 text-center text-muted-foreground">
      <FileQuestion className="size-6" />
      <p className="text-sm font-medium">{title}</p>
      <p className="text-xs">No current record exists for this company yet.</p>
    </div>
  );
}
