// GymBro Mobile — Session detail / progress summary. Mirrors the portal
// session-detail-dialog: summary metrics + per-exercise set breakdown, PRs,
// repeat-workout. Opens after finishing a session, or from a timeline row.

function StatTile({ icon, value, unit, label, accent }) {
  return (
    <div style={{
      flex: 1, background: 'var(--gb-card)', border: '1px solid var(--inv-border-card)',
      borderRadius: 'var(--gb-r-md)', padding: '13px 14px', boxShadow: 'var(--gb-shadow-sm)',
    }}>
      <Icon name={icon} size={18} color={accent || 'var(--inv-grey-400)'} />
      <div className="gb-num" style={{ marginTop: 9, display: 'flex', alignItems: 'baseline', gap: 3 }}>
        <span style={{ fontSize: 23, fontWeight: 800, color: 'var(--gb-ink)', letterSpacing: '-0.03em' }}>{value}</span>
        {unit && <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--inv-grey-400)' }}>{unit}</span>}
      </div>
      <div className="gb-eyebrow" style={{ color: 'var(--inv-grey-400)', marginTop: 2 }}>{label}</div>
    </div>
  );
}

function SessionDetailScreen({ platform, onBack, fromFinish }) {
  const d = SESSION_DETAIL;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--gb-canvas)' }}>
      {/* Header */}
      <div style={{ flexShrink: 0, paddingTop: safeTop(platform), background: 'var(--inv-surface-base)', borderBottom: '1px solid var(--inv-border-card)' }}>
        <div style={{ padding: '8px 12px 12px', display: 'flex', alignItems: 'center', gap: 8 }}>
          <button onClick={onBack} style={{ width: 40, height: 40, borderRadius: '50%', border: 'none', background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name={fromFinish ? 'x' : 'chevL'} size={20} color="var(--inv-grey-700)" />
          </button>
          <div style={{ flex: 1, fontSize: 16, fontWeight: 800, color: 'var(--inv-grey-900)' }}>{fromFinish ? 'Workout complete' : 'Session detail'}</div>
          <button style={{ width: 40, height: 40, borderRadius: '50%', border: 'none', background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name="more" size={20} color="var(--inv-grey-700)" />
          </button>
        </div>
      </div>

      {/* Body */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 18px 16px' }}>
        {fromFinish && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 14, borderRadius: 'var(--gb-r-md)', marginBottom: 16,
            background: 'var(--gb-emerald-soft)', border: '1px solid rgba(16,185,129,0.25)' }}>
            <div style={{ width: 44, height: 44, borderRadius: '50%', background: 'var(--gb-emerald)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 12px -3px rgba(16,185,129,0.55)' }}>
              <Icon name="check" size={24} color="#fff" strokeWidth={2.8} />
            </div>
            <div>
              <div style={{ fontSize: 15.5, fontWeight: 800, color: 'var(--gb-emerald-ink)', letterSpacing: '-0.01em' }}>Nice work, Alex!</div>
              <div style={{ fontSize: 13, color: 'var(--gb-emerald-ink)', opacity: 0.8 }}>Session saved to your log.</div>
            </div>
          </div>
        )}

        {/* Title */}
        <div style={{ marginBottom: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
            <span style={{ fontSize: 25, fontWeight: 800, color: 'var(--gb-ink)', letterSpacing: '-0.03em', whiteSpace: 'nowrap' }}>{d.name}</span>
            <SourceTag source="plan" />
            {d.prCount > 0 && <PRChip />}
          </div>
          <div style={{ fontSize: 13, color: 'var(--inv-grey-500)', marginTop: 4 }}>{d.program} · {d.day} · {d.date} · {d.startedAt}</div>
        </div>

        {/* Stat grid */}
        <div style={{ display: 'flex', gap: 10, marginBottom: 10 }}>
          <StatTile icon="clock" value={fmtDuration(d.dur)} label="DURATION" />
          <StatTile icon="bars" value={fmtVolume(d.volumeKg)} unit="kg" label="VOLUME" accent="var(--inv-primary-500)" />
        </div>
        <div style={{ display: 'flex', gap: 10, marginBottom: 18 }}>
          <StatTile icon="layers" value={d.totalSets} label="SETS" />
          <StatTile icon="flame" value={d.rpe} unit="/10" label="AVG RPE" accent="var(--inv-warning-100)" />
          <StatTile icon="trophy" value={d.prCount} label="PRS" accent="var(--inv-warning-200)" />
        </div>

        {/* Exercise breakdown */}
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--inv-grey-900)', marginBottom: 10 }}>
          Exercises <span style={{ color: 'var(--inv-grey-400)', fontWeight: 600 }}>· {d.exercises.length}</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {d.exercises.map((e, i) => {
            const vol = e.sets.reduce((n, s) => n + s.kg * s.reps, 0);
            const best = Math.max(0, ...e.sets.map(s => e1rm(s.kg, s.reps) || 0));
            return (
              <div key={i} style={{ background: 'var(--gb-card)', border: '1px solid var(--inv-border-card)', borderRadius: 'var(--gb-r-md)', padding: 14, boxShadow: 'var(--gb-shadow-sm)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                      <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--inv-grey-900)' }}>{e.name}</span>
                      {e.pr && <PRChip small />}
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--inv-grey-500)', marginTop: 1 }}>
                      {e.muscle} · {e.sets.length} sets · {fmtVolume(vol)}kg{best > 0 ? ` · e1RM ${best}kg` : ''}
                    </div>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 7, flexWrap: 'wrap' }}>
                  {e.sets.map((s, si) => {
                    const top = e.pr && si === e.sets.length - 1;
                    return (
                      <span key={si} style={{
                        display: 'inline-flex', alignItems: 'center', gap: 5, borderRadius: 9, padding: '5px 10px',
                        fontSize: 13, fontWeight: 700,
                        background: top ? 'var(--gb-amber-soft)' : 'var(--inv-grey-0)',
                        border: `1px solid ${top ? 'rgba(245,158,11,0.3)' : 'var(--inv-border-card)'}`,
                        color: top ? 'var(--gb-amber-ink)' : 'var(--inv-grey-700)', whiteSpace: 'nowrap',
                      }} className="gb-num">
                        {top && <Icon name="trophy" size={12} color="var(--gb-amber)" />}
                        {s.kg}kg × {s.reps}
                      </span>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Action bar */}
      <div style={{ flexShrink: 0, padding: `12px 16px ${bottomInset(platform) + 12}px`, background: 'var(--inv-surface-base)', borderTop: '1px solid var(--inv-border-card)', display: 'flex', gap: 10 }}>
        <GbButton severity="secondary" outlined icon="history" label="" style={{ width: 52, padding: 0 }} />
        <GbButton full icon="play" label="Repeat workout" onClick={onBack} style={{ flex: 1 }} />
      </div>
    </div>
  );
}

Object.assign(window, { SessionDetailScreen });
