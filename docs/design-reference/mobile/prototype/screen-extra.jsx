// GymBro Mobile — secondary tabs (Plan, Progress, Profile). Kept compact but
// on-brand so the tab bar has no dead ends. Plan = trainee read-only plan view;
// Progress = computed stats; Profile = mirrors profile/settings panels.

function PlainHeader({ platform, title, subtitle }) {
  return (
    <div style={{ flexShrink: 0, paddingTop: safeTop(platform), background: 'var(--inv-surface-base)', borderBottom: '1px solid var(--inv-border-card)' }}>
      <div style={{ padding: '8px 18px 14px' }}>
        <div style={{ fontSize: 23, fontWeight: 800, color: 'var(--gb-ink)', letterSpacing: '-0.03em' }}>{title}</div>
        {subtitle && <div style={{ fontSize: 13, color: 'var(--inv-grey-500)', marginTop: 2 }}>{subtitle}</div>}
      </div>
    </div>
  );
}

function PlanScreen({ platform }) {
  const [day, setDay] = React.useState(0);
  const days = ['Day A', 'Day B', 'Day C', 'Day D'];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--gb-canvas)' }}>
      <PlainHeader platform={platform} title="My Plan" subtitle="Assigned by Coach Morgan" />
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 18px 90px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div style={{ borderRadius: 'var(--gb-r-lg)', padding: 18, color: '#fff', position: 'relative', overflow: 'hidden', background: 'var(--gb-hero)', boxShadow: 'var(--gb-shadow-blue), inset 0 1px 0 rgba(255,255,255,0.22)' }}>
          <div style={{ position: 'absolute', right: -50, top: -50, width: 180, height: 180, borderRadius: '50%', background: 'radial-gradient(circle, rgba(120,180,255,0.4), transparent 70%)' }} />
          <div className="gb-eyebrow" style={{ position: 'relative', color: '#bfdbfe' }}>Current program</div>
          <div style={{ position: 'relative', fontSize: 21, fontWeight: 800, marginTop: 5, letterSpacing: '-0.02em' }}>{TODAY_WORKOUT.program}</div>
          <div style={{ position: 'relative', display: 'flex', gap: 20, marginTop: 16 }}>
            {[['Week', `${TODAY_WORKOUT.week} / 8`], ['Days', '4 / wk'], ['Visibility', 'Full']].map(([l, v]) => (
              <div key={l}>
                <div className="gb-num" style={{ fontSize: 17, fontWeight: 800, whiteSpace: 'nowrap' }}>{v}</div>
                <div className="gb-eyebrow" style={{ color: 'rgba(255,255,255,0.66)', marginTop: 2 }}>{l}</div>
              </div>
            ))}
          </div>
        </div>

        <div style={{ display: 'flex', gap: 8, overflowX: 'auto' }}>
          {days.map((dl, i) => {
            const on = i === day;
            return (
              <button key={dl} onClick={() => setDay(i)} style={{
                flexShrink: 0, height: 36, padding: '0 16px', borderRadius: 999, cursor: 'pointer', whiteSpace: 'nowrap',
                border: `1.5px solid ${on ? 'var(--inv-primary-500)' : 'var(--inv-border-card)'}`,
                background: on ? 'var(--inv-primary-500)' : 'var(--inv-surface-base)',
                color: on ? '#fff' : 'var(--inv-grey-600)', font: '700 13px var(--inv-font-sans)',
              }}>{dl}</button>
            );
          })}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 15, fontWeight: 800, color: 'var(--gb-ink)', whiteSpace: 'nowrap' }}>{day === 0 ? 'Push Day' : days[day]}</span>
          <SourceTag source="plan" small />
          <span style={{ flex: 1 }} />
          <span style={{ fontSize: 12, color: 'var(--inv-grey-400)', whiteSpace: 'nowrap' }}>{day === 0 ? '5 exercises' : '—'}</span>
        </div>

        {(day === 0 ? TODAY_WORKOUT.exercises : []).map((e, i) => (
          <div key={e.id} style={{ background: 'var(--gb-card)', border: '1px solid var(--inv-border-card)', borderRadius: 'var(--gb-r-md)', padding: 14, boxShadow: 'var(--gb-shadow-sm)', display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 36, height: 36, borderRadius: 11, background: 'var(--inv-primary-0)', color: 'var(--inv-primary-700)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: 14 }} className="gb-num">{i + 1}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--gb-ink)' }}>{e.name}</div>
              <div className="gb-num" style={{ fontSize: 12, color: 'var(--inv-grey-500)' }}>{e.sets.length} × {e.sets[e.sets.length - 1].reps} @ {e.sets[e.sets.length - 1].kg}kg · {e.muscle}</div>
            </div>
            <Icon name="chevR" size={16} color="var(--inv-grey-300)" />
          </div>
        ))}
        {day !== 0 && (
          <div style={{ textAlign: 'center', padding: 30, color: 'var(--inv-grey-400)' }}>
            <Icon name="calendar" size={28} color="var(--inv-grey-300)" style={{ margin: '0 auto 8px' }} />
            <div style={{ fontSize: 13 }}>Tap a day to preview its workout</div>
          </div>
        )}
      </div>
    </div>
  );
}

function ProgressScreen({ platform }) {
  const weeks = [
    { w: 'Wk 1', v: 9.1 }, { w: 'Wk 2', v: 11.4 }, { w: 'Wk 3', v: 10.3 },
  ];
  const max = 12;
  const prs = [
    { name: 'Deadlift', val: '120 kg × 3', when: 'Mon' },
    { name: 'Barbell Row', val: '50 kg × 10', when: 'Last week' },
    { name: 'Bench Press', val: '65 kg × 8', when: '2 weeks ago' },
  ];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--gb-canvas)' }}>
      <PlainHeader platform={platform} title="Progress" subtitle="Hypertrophy Block A" />
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 18px 90px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div style={{ display: 'flex', gap: 10 }}>
          <StatTile icon="history" value="23" label="SESSIONS" />
          <StatTile icon="bars" value="98.4" unit="k" label="TOTAL kg" accent="var(--inv-primary-500)" />
          <StatTile icon="trophy" value="7" label="PRS" accent="var(--inv-warning-200)" />
        </div>

        <div style={{ background: 'var(--gb-card)', border: '1px solid var(--inv-border-card)', borderRadius: 'var(--gb-r-lg)', padding: 18, boxShadow: 'var(--gb-shadow)' }}>
          <Eyebrow color="var(--inv-grey-400)" style={{ marginBottom: 16 }}>Weekly volume · k kg</Eyebrow>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 14, height: 124, padding: '0 6px' }}>
            {weeks.map((wk, i) => {
              const last = i === weeks.length - 1;
              return (
                <div key={wk.w} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
                  <div className="gb-num" style={{ fontSize: 12.5, fontWeight: 800, color: last ? 'var(--inv-primary-700)' : 'var(--inv-grey-500)' }}>{wk.v}</div>
                  <div style={{ width: '100%', height: (wk.v / max * 92), borderRadius: '10px 10px 4px 4px',
                    background: last ? 'var(--gb-hero)' : 'var(--inv-primary-100)',
                    boxShadow: last ? '0 6px 14px -6px rgba(37,99,235,0.55)' : 'none' }} />
                  <div className="gb-eyebrow" style={{ color: 'var(--inv-grey-400)' }}>{wk.w}</div>
                </div>
              );
            })}
          </div>
        </div>

        <div style={{ fontSize: 14, fontWeight: 800, color: 'var(--gb-ink)', letterSpacing: '-0.01em' }}>Recent personal records</div>
        {prs.map(p => (
          <div key={p.name} style={{ background: 'var(--gb-card)', border: '1px solid var(--inv-border-card)', borderRadius: 'var(--gb-r-md)', padding: 13, boxShadow: 'var(--gb-shadow-sm)', display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 40, height: 40, borderRadius: 12, background: 'var(--gb-amber-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="trophy" size={20} color="var(--gb-amber)" />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--gb-ink)' }}>{p.name}</div>
              <div className="gb-num" style={{ fontSize: 12.5, color: 'var(--inv-grey-500)' }}>{p.val}</div>
            </div>
            <span style={{ fontSize: 12, color: 'var(--inv-grey-400)', whiteSpace: 'nowrap' }}>{p.when}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function ProfileScreen({ platform, onSignOut, coach }) {
  const id = coach
    ? { initial: 'M', name: 'Morgan Hale', email: 'morgan@halestrength.co', role: 'Owner · Hale Strength' }
    : { initial: 'A', name: 'Alex Rivera', email: 'alex@trainwith.me', role: 'Client · Coach Morgan' };
  const items = coach ? [
    { icon: 'user', label: 'My profile' },
    { icon: 'users', label: 'Workspace & members' },
    { icon: 'ticket', label: 'Invites' },
    { icon: 'key', label: 'Change password' },
    { icon: 'settings', label: 'Settings' },
  ] : [
    { icon: 'user', label: 'My profile' },
    { icon: 'ticket', label: 'Join a coach', sub: 'Enter an invite code' },
    { icon: 'bell', label: 'Notifications' },
    { icon: 'key', label: 'Change password' },
    { icon: 'settings', label: 'Settings' },
  ];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--gb-canvas)' }}>
      <PlainHeader platform={platform} title="Profile" />
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 18px 90px', display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: 16, background: 'var(--gb-card)', border: '1px solid var(--inv-border-card)', borderRadius: 'var(--gb-r-lg)', boxShadow: 'var(--gb-shadow)' }}>
          <Avatar initial={id.initial} size={56} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--gb-ink)', letterSpacing: '-0.01em' }}>{id.name}</div>
            <div style={{ fontSize: 13, color: 'var(--inv-grey-500)' }}>{id.email}</div>
            <span style={{ display: 'inline-block', marginTop: 7, fontSize: 11, fontWeight: 700, color: 'var(--inv-primary-700)', background: 'var(--inv-primary-0)', borderRadius: 7, padding: '3px 9px', whiteSpace: 'nowrap' }}>{id.role}</span>
          </div>
        </div>

        <div style={{ background: 'var(--gb-card)', border: '1px solid var(--inv-border-card)', borderRadius: 'var(--gb-r-lg)', overflow: 'hidden', boxShadow: 'var(--gb-shadow-sm)' }}>
          {items.map((it, i) => (
            <button key={it.label} style={{
              width: '100%', textAlign: 'left', cursor: 'pointer', background: 'none',
              border: 'none', borderBottom: i < items.length - 1 ? '1px solid var(--inv-border-card)' : 'none',
              padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 14,
            }}>
              <Icon name={it.icon} size={20} color="var(--inv-grey-500)" />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 15, fontWeight: 600, color: 'var(--inv-grey-900)' }}>{it.label}</div>
                {it.sub && <div style={{ fontSize: 12, color: 'var(--inv-grey-400)' }}>{it.sub}</div>}
              </div>
              <Icon name="chevR" size={16} color="var(--inv-grey-300)" />
            </button>
          ))}
        </div>

        <GbButton full severity="danger" text label="Sign out" onClick={onSignOut} />
        <div style={{ textAlign: 'center', fontSize: 11, color: 'var(--inv-grey-400)' }}>GymBro Mobile · v1.0.0 (prototype)</div>
      </div>
    </div>
  );
}

Object.assign(window, { PlanScreen, ProgressScreen, ProfileScreen });
