// GymBro Mobile — Workout Log (home). Session-first timeline mirroring
// features/workspace/logs: active-session hero, this-week ring, filter chips,
// collapsible Monday-anchored week groups, kg volume. Start → bottom sheet.

function HeroBanner({ onResume }) {
  const hero = WEEK_GROUPS[0].items.find(i => i.status === 'active');
  if (!hero) return null;
  const pct = Math.round((hero.doneSets / hero.sets) * 100);
  return (
    <div style={{
      flexShrink: 0,
      borderRadius: 'var(--gb-r-lg)', padding: 18, color: '#fff', position: 'relative', overflow: 'hidden',
      background: 'var(--gb-hero)',
      boxShadow: 'var(--gb-shadow-blue), inset 0 1px 0 rgba(255,255,255,0.22)',
    }}>
      {/* depth mesh */}
      <div style={{ position: 'absolute', right: -50, top: -60, width: 200, height: 200, borderRadius: '50%', background: 'radial-gradient(circle, rgba(120,180,255,0.45), transparent 70%)' }} />
      <div style={{ position: 'absolute', left: -40, bottom: -70, width: 180, height: 180, borderRadius: '50%', background: 'radial-gradient(circle, rgba(99,102,241,0.4), transparent 70%)' }} />

      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div className="gb-eyebrow" style={{ display: 'inline-flex', alignItems: 'center', gap: 7, color: '#bfdbfe' }}>
          <span style={{ position: 'relative', display: 'inline-flex' }}>
            <span style={{ width: 7, height: 7, borderRadius: '50%', background: '#34d399' }} />
            <span style={{ position: 'absolute', inset: -3, borderRadius: '50%', border: '2px solid rgba(52,211,153,0.5)', animation: 'gbPulse 1.6s ease-out infinite' }} />
          </span>
          Live session
        </div>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 12.5, fontWeight: 700, background: 'rgba(255,255,255,0.16)', borderRadius: 999, padding: '3px 10px' }}>
          <Icon name="clock" size={13} color="#fff" /><span className="gb-num">24:18</span>
        </span>
      </div>

      <div style={{ position: 'relative', fontSize: 25, fontWeight: 800, marginTop: 10, letterSpacing: '-0.02em' }}>{hero.name}</div>
      <div style={{ position: 'relative', fontSize: 13, color: 'rgba(255,255,255,0.72)', marginTop: 2 }}>{TODAY_WORKOUT.program} · {TODAY_WORKOUT.day}</div>

      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 16, marginBottom: 6 }}>
        <span style={{ fontSize: 12.5, fontWeight: 700, color: 'rgba(255,255,255,0.82)' }}>
          <span className="gb-num" style={{ fontSize: 15, fontWeight: 800, color: '#fff' }}>{hero.doneSets}</span> of {hero.sets} sets
        </span>
        <span className="gb-num" style={{ fontSize: 15, fontWeight: 800 }}>{pct}%</span>
      </div>
      <div style={{ position: 'relative', height: 9, borderRadius: 999, background: 'rgba(255,255,255,0.2)', overflow: 'hidden' }}>
        <div style={{ width: pct + '%', height: '100%', background: 'linear-gradient(90deg, #a5f3d0, #fff)', borderRadius: 999, boxShadow: '0 0 12px rgba(255,255,255,0.7)' }} />
      </div>

      <button onClick={onResume} style={{
        position: 'relative', width: '100%', height: 48, borderRadius: 'var(--gb-r-sm)', border: 'none', cursor: 'pointer', marginTop: 16,
        background: '#fff', color: 'var(--inv-primary-700)', font: '800 15px var(--inv-font-sans)', letterSpacing: '-0.01em', whiteSpace: 'nowrap',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, boxShadow: '0 6px 16px -6px rgba(0,0,0,0.4)',
      }}>
        <Icon name="play" size={18} color="var(--inv-primary-700)" /> Resume workout
      </button>
    </div>
  );
}

function WeekCard() {
  const w = THIS_WEEK;
  return (
    <div style={{
      flexShrink: 0,
      background: 'var(--gb-card)', border: '1px solid var(--inv-border-card)',
      borderRadius: 'var(--gb-r-lg)', padding: 18, boxShadow: 'var(--gb-shadow)',
      display: 'flex', alignItems: 'center', gap: 18,
    }}>
      <Ring value={w.done} total={w.goal} size={70} stroke={8} gradient={['#60a5fa', '#1d4ed8']}>
        <div style={{ textAlign: 'center' }}>
          <div className="gb-num" style={{ fontSize: 21, fontWeight: 800, lineHeight: 1, color: 'var(--gb-ink)' }}>{w.done}</div>
          <div className="gb-num" style={{ fontSize: 10, color: 'var(--inv-grey-400)', fontWeight: 700 }}>of {w.goal}</div>
        </div>
      </Ring>
      <div style={{ flex: 1 }}>
        <Eyebrow color="var(--inv-grey-400)">This week</Eyebrow>
        <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--gb-ink)', marginTop: 3, letterSpacing: '-0.01em' }}>1 session to your goal</div>
        <div style={{ display: 'flex', gap: 22, marginTop: 12 }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 2 }}>
              <span className="gb-num" style={{ fontSize: 17, fontWeight: 800, color: 'var(--gb-ink)' }}>{fmtVolume(w.volumeKg)}</span>
              <span style={{ fontSize: 11, color: 'var(--inv-grey-400)', fontWeight: 600 }}>kg</span>
            </div>
            <Eyebrow color="var(--inv-grey-400)" style={{ marginTop: 1 }}>Volume</Eyebrow>
          </div>
          <div>
            <span className="gb-num" style={{ fontSize: 17, fontWeight: 800, color: 'var(--gb-ink)' }}>{w.sets}</span>
            <Eyebrow color="var(--inv-grey-400)" style={{ marginTop: 1 }}>Sets</Eyebrow>
          </div>
        </div>
      </div>
    </div>
  );
}

function SessionRow({ s, onClick }) {
  return (
    <button onClick={onClick} style={{
      width: '100%', textAlign: 'left', cursor: 'pointer', background: 'var(--gb-card)',
      border: '1px solid var(--inv-border-card)', borderRadius: 'var(--gb-r-md)', padding: 12,
      display: 'flex', gap: 12, alignItems: 'center', marginBottom: 9, boxShadow: 'var(--gb-shadow-sm)',
    }}>
      <DayBadge day={s.day} status={s.status} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, flexWrap: 'wrap' }}>
          <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--inv-grey-900)' }}>{s.name}</span>
          <SourceTag source={s.source} small />
          {s.status === 'abandoned' && <span style={{ fontSize: 11, color: 'var(--inv-error-200)', fontWeight: 600 }}>· stopped early</span>}
          {s.status === 'active' && <span style={{ fontSize: 11, color: 'var(--inv-primary-600)', fontWeight: 700 }}>· live</span>}
        </div>
        <div style={{ display: 'flex', gap: 12, marginTop: 5, color: 'var(--inv-grey-500)', fontSize: 12, flexWrap: 'wrap' }}>
          <span>{s.rel}</span>
          {s.dur && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}><Icon name="clock" size={12} />{fmtDuration(s.dur)}</span>}
          {s.vol > 0 && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}><Icon name="bars" size={12} />{fmtVolume(s.vol)}kg</span>}
        </div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 5 }}>
        {s.pr > 0 && <PRChip small />}
        {s.rpe != null && <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--inv-grey-400)' }}>RPE {s.rpe}</span>}
        <Icon name="chevR" size={16} color="var(--inv-grey-300)" />
      </div>
    </button>
  );
}

function WorkoutLogScreen({ platform, onResume, onOpenSession, onStart }) {
  const [filter, setFilter] = React.useState('all');
  const [openWeeks, setOpenWeeks] = React.useState({ 0: true, 1: false });
  const [sheet, setSheet] = React.useState(false);

  const allItems = WEEK_GROUPS.flatMap(w => w.items);
  const counts = {
    all: allItems.length,
    done: allItems.filter(i => i.status === 'done').length,
    active: allItems.filter(i => i.status === 'active').length,
    abandoned: allItems.filter(i => i.status === 'abandoned').length,
  };
  const chips = [
    { id: 'all', label: 'All', icon: 'layers' },
    { id: 'done', label: 'Completed', icon: 'check' },
    { id: 'active', label: 'In progress', icon: 'play' },
    { id: 'abandoned', label: 'Abandoned', icon: 'flag' },
  ];
  const matches = s => filter === 'all' || s.status === filter;

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--gb-canvas)' }}>
      {/* Sticky header */}
      <div style={{
        flexShrink: 0, paddingTop: safeTop(platform), background: 'var(--inv-surface-base)',
        borderBottom: '1px solid var(--inv-border-card)',
      }}>
        <div style={{ padding: '8px 18px 13px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <Avatar initial="A" size={42} ring />
          <div style={{ flex: 1, minWidth: 0 }}>
            <Eyebrow color="var(--inv-grey-400)">Good evening</Eyebrow>
            <div style={{ fontSize: 19, fontWeight: 800, color: 'var(--gb-ink)', letterSpacing: '-0.02em', marginTop: 1 }}>Alex Rivera</div>
          </div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 5, height: 30, padding: '0 11px', borderRadius: 999, background: 'var(--gb-amber-soft)' }}>
            <Icon name="flame" size={15} color="var(--gb-amber)" />
            <span className="gb-num" style={{ fontSize: 13, fontWeight: 800, color: 'var(--gb-amber-ink)' }}>12</span>
          </div>
          <button style={{ position: 'relative', width: 40, height: 40, borderRadius: '50%', border: '1px solid var(--inv-border-card)', background: 'var(--inv-surface-base)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name="bell" size={19} color="var(--inv-grey-600)" />
            <span style={{ position: 'absolute', top: 8, right: 9, width: 8, height: 8, borderRadius: '50%', background: 'var(--inv-error-100)', border: '1.5px solid #fff' }} />
          </button>
        </div>
      </div>

      {/* Scroll body */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 18px 22px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        <HeroBanner onResume={onResume} />
        <WeekCard />

        {/* Filter chips */}
        <div style={{ flexShrink: 0, display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 2, margin: '0 -18px', padding: '0 18px' }}>
          {chips.map(c => {
            const on = filter === c.id;
            return (
              <button key={c.id} onClick={() => setFilter(c.id)} style={{
                flexShrink: 0, display: 'inline-flex', alignItems: 'center', gap: 6, height: 36, padding: '0 14px', whiteSpace: 'nowrap',
                borderRadius: 999, cursor: 'pointer', font: '700 13px var(--inv-font-sans)', letterSpacing: '-0.01em',
                border: `1.5px solid ${on ? 'transparent' : 'var(--inv-border-card)'}`,
                background: on ? 'var(--gb-ink)' : 'var(--inv-surface-base)',
                color: on ? '#fff' : 'var(--inv-grey-600)',
                boxShadow: on ? 'var(--gb-shadow-sm)' : 'none',
              }}>
                <Icon name={c.icon} size={14} />{c.label}
                <span className="gb-num" style={{ fontSize: 11, fontWeight: 800, opacity: on ? 0.7 : 0.5 }}>{counts[c.id]}</span>
              </button>
            );
          })}
        </div>

        {/* Week groups */}
        {WEEK_GROUPS.map((wk, wi) => {
          const visible = wk.items.filter(matches);
          if (visible.length === 0) return null;
          const open = openWeeks[wi];
          return (
            <div key={wi} style={{ flexShrink: 0 }}>
              <button onClick={() => setOpenWeeks(o => ({ ...o, [wi]: !o[wi] }))} style={{
                width: '100%', display: 'flex', alignItems: 'center', gap: 8, background: 'none', border: 'none',
                cursor: 'pointer', padding: '4px 2px 10px',
              }}>
                <Icon name="chevR" size={16} color="var(--inv-grey-400)"
                  style={{ transform: open ? 'rotate(90deg)' : 'none', transition: 'transform .2s' }} />
                <span style={{ fontSize: 14, fontWeight: 800, color: 'var(--gb-ink)', letterSpacing: '-0.01em' }}>{wk.label}</span>
                <span style={{ fontSize: 12, color: 'var(--inv-grey-400)' }}>{wk.source}</span>
                <span style={{ flex: 1 }} />
                {wk.prCount > 0 && <PRChip small />}
                <span className="gb-num" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 800, color: 'var(--inv-grey-600)' }}>
                  <Ring value={wk.done} total={wk.goal} size={24} stroke={3.5} gradient={['#60a5fa', '#1d4ed8']} />{wk.done}/{wk.goal}
                </span>
              </button>
              {open && visible.map(s => (
                <SessionRow key={s.id} s={s}
                  onClick={() => s.status === 'active' ? onResume() : onOpenSession()} />
              ))}
            </div>
          );
        })}
      </div>

      {/* Start FAB-style button above tab bar */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 30, pointerEvents: 'none' }}>
        <div style={{ display: 'flex', justifyContent: 'center', paddingBottom: 16 }}>
          <button onClick={() => setSheet(true)} style={{
            pointerEvents: 'auto', height: 52, padding: '0 24px', borderRadius: 999, border: 'none', cursor: 'pointer',
            background: 'var(--gb-hero)', color: '#fff', font: '800 15px var(--inv-font-sans)', letterSpacing: '-0.01em',
            display: 'inline-flex', alignItems: 'center', gap: 9, boxShadow: 'var(--gb-shadow-blue), inset 0 1px 0 rgba(255,255,255,0.25)',
          }}>
            <Icon name="plus" size={20} /> Start Workout
          </button>
        </div>
      </div>

      {/* Start session bottom sheet */}
      <BottomSheet open={sheet} onClose={() => setSheet(false)}>
        <div style={{ padding: '6px 20px 24px' }}>
          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--inv-grey-900)' }}>Start a workout</div>
          <div style={{ fontSize: 13, color: 'var(--inv-grey-500)', marginTop: 3, marginBottom: 14 }}>Pick one of your active assignments, or log an ad-hoc session.</div>

          <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', padding: '11px 12px', borderRadius: 11, background: 'var(--inv-warning-0)', border: '1px solid var(--inv-warning-50)', marginBottom: 14 }}>
            <Icon name="play" size={16} color="var(--inv-warning-200)" style={{ marginTop: 1 }} />
            <div style={{ fontSize: 12.5, color: 'var(--inv-warning-300)', lineHeight: 1.5 }}>
              You have an <b>active Push Day</b> session. One workout runs at a time — starting will resume it.
            </div>
          </div>

          <div style={{ fontSize: 11.5, fontWeight: 700, color: 'var(--inv-grey-400)', letterSpacing: '0.06em', marginBottom: 8 }}>YOUR ASSIGNMENTS</div>
          {MY_ASSIGNMENTS.map(a => (
            <button key={a.id} onClick={() => { setSheet(false); onStart(); }} style={{
              width: '100%', textAlign: 'left', cursor: 'pointer', marginBottom: 8,
              background: 'var(--inv-surface-base)', border: '1.5px solid var(--inv-border-card)', borderRadius: 14, padding: 13,
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{ width: 42, height: 42, borderRadius: 11, background: 'var(--inv-primary-0)', color: 'var(--inv-primary-600)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="bolt" size={21} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 7, flexWrap: 'wrap' }}>
                  <span style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--inv-grey-900)' }}>{a.plan}</span>
                  <VisBadge mode={a.visibility} />
                </div>
                <div style={{ fontSize: 12, color: 'var(--inv-grey-500)', marginTop: 1 }}>{a.day} · {a.exercises} exercises · {a.sets} sets</div>
              </div>
              <Icon name="chevR" size={18} color="var(--inv-grey-300)" />
            </button>
          ))}

          <button onClick={() => { setSheet(false); onStart(); }} style={{
            width: '100%', textAlign: 'left', cursor: 'pointer', marginTop: 4,
            background: 'var(--inv-surface-base)', border: '1.5px dashed var(--inv-border-field)', borderRadius: 14, padding: 13,
            display: 'flex', alignItems: 'center', gap: 12,
          }}>
            <div style={{ width: 42, height: 42, borderRadius: 11, background: 'var(--inv-grey-25)', color: 'var(--inv-grey-600)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="plus" size={21} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--inv-grey-900)' }}>Ad-hoc workout</div>
              <div style={{ fontSize: 12, color: 'var(--inv-grey-500)' }}>No assignment · build it as you go</div>
            </div>
            <Icon name="chevR" size={18} color="var(--inv-grey-400)" />
          </button>
        </div>
      </BottomSheet>
    </div>
  );
}

Object.assign(window, { WorkoutLogScreen });
