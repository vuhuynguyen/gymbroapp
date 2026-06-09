// GymBro Mobile — Live Active Session. Full-screen focus mode mirroring
// features/workspace/logs/active-session: log sets, rest timer, substitute,
// skip, complete/abandon. Weights in kg (the stored unit).

function deepSets() {
  return TODAY_WORKOUT.exercises.map((e, ei) => ({
    ...e,
    name: e.name,
    sets: e.sets.map((s, si) => ({ ...s, done: ei === 0 || (ei === 1 && si === 0), skipped: false })),
  }));
}

function Stepper({ value, unit, step, onChange, big }) {
  const sz = big ? 40 : 34;
  const btn = dir => (
    <button onClick={() => onChange(Math.max(0, +(value + dir * step).toFixed(2)))} style={{
      width: sz, height: sz, borderRadius: 11, cursor: 'pointer',
      border: '1.5px solid var(--inv-border-card)', background: 'var(--inv-grey-0)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
    }}>
      <Icon name={dir < 0 ? 'minus' : 'plus'} size={big ? 20 : 16} color="var(--inv-grey-700)" />
    </button>
  );
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, justifyContent: 'center' }}>
      {btn(-1)}
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'center', minWidth: big ? 46 : 34 }}>
        <input type="number" inputMode="decimal" value={value} className="gb-num"
          onChange={e => onChange(e.target.value === '' ? 0 : Math.max(0, +e.target.value))}
          onFocus={e => e.target.select()}
          style={{
            width: big ? 52 : 38, border: 'none', background: 'transparent', textAlign: 'center',
            font: `800 ${big ? 27 : 18}px var(--inv-font-sans)`, color: 'var(--gb-ink)',
            padding: 0, outline: 'none', MozAppearance: 'textfield',
          }} />
        {unit && <span style={{ fontSize: big ? 13 : 11, fontWeight: 600, color: 'var(--inv-grey-400)' }}>{unit}</span>}
      </div>
      {btn(1)}
    </div>
  );
}

function ActiveSessionScreen({ platform, onComplete, onAbandon }) {
  const [exs, setExs] = React.useState(deepSets);
  const [cur, setCur] = React.useState(1);
  const [elapsed, setElapsed] = React.useState(1458);
  const [rest, setRest] = React.useState(null); // {remaining, total}
  const [sheet, setSheet] = React.useState(null); // 'sub' | 'skip' | 'abandon' | 'more' | 'add'
  const [muscleFilter, setMuscleFilter] = React.useState('All');

  // elapsed timer
  React.useEffect(() => {
    const t = setInterval(() => setElapsed(e => e + 1), 1000);
    return () => clearInterval(t);
  }, []);
  // rest countdown
  React.useEffect(() => {
    if (!rest) return;
    if (rest.remaining <= 0) { setRest(null); return; }
    const t = setTimeout(() => setRest(r => r && { ...r, remaining: r.remaining - 1 }), 1000);
    return () => clearTimeout(t);
  }, [rest]);

  const ex = exs[cur];
  const totalSets = exs.reduce((n, e) => n + e.sets.length, 0);
  const doneSets = exs.reduce((n, e) => n + e.sets.filter(s => s.done).length, 0);
  const allDone = exs.every(e => e.sets.every(s => s.done || s.skipped));
  const curSetIdx = ex.sets.findIndex(s => !s.done && !s.skipped);

  function logSet(si) {
    setExs(prev => prev.map((e, ei) => ei !== cur ? e : {
      ...e, sets: e.sets.map((s, j) => j === si ? { ...s, done: true } : s),
    }));
    setRest({ remaining: ex.rest, total: ex.rest });
  }
  function editSet(si, field, val) {
    setExs(prev => prev.map((e, ei) => ei !== cur ? e : {
      ...e, sets: e.sets.map((s, j) => j === si ? { ...s, [field]: val } : s),
    }));
  }
  function cycleType(si) {
    const order = ['warmup', 'working', 'drop', 'amrap'];
    setExs(prev => prev.map((e, ei) => ei !== cur ? e : {
      ...e, sets: e.sets.map((s, j) => j === si ? { ...s, type: order[(order.indexOf(s.type) + 1) % order.length] } : s),
    }));
  }
  function substitute(name, equipment) {
    setExs(prev => prev.map((e, ei) => ei !== cur ? e : { ...e, name, equipment }));
    setSheet(null);
  }
  function skipExercise() {
    setExs(prev => prev.map((e, ei) => ei !== cur ? e : {
      ...e, sets: e.sets.map(s => s.done ? s : { ...s, skipped: true }),
    }));
    setSheet(null);
    if (cur < exs.length - 1) setCur(cur + 1);
  }
  function addExercise(item) {
    const ne = {
      id: 'x' + Date.now(), name: item.name, muscle: item.muscle, equipment: item.equipment, rest: 90,
      sets: [0, 1, 2].map(() => ({ type: 'working', reps: item.reps, kg: item.kg, done: false, skipped: false })),
    };
    setCur(exs.length);
    setExs(prev => [...prev, ne]);
    setSheet(null);
  }
  function addSet() {
    setExs(prev => prev.map((e, ei) => {
      if (ei !== cur) return e;
      const last = e.sets[e.sets.length - 1] || { reps: 10, kg: 20 };
      return { ...e, sets: [...e.sets, { type: 'working', reps: last.reps, kg: last.kg, done: false, skipped: false }] };
    }));
  }

  const exDone = ex.sets.every(s => s.done || s.skipped);
  const exHasLogged = ex.sets.some(s => s.done);

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--gb-canvas)', position: 'relative' }}>
      {/* Gradient focus header */}
      <div style={{
        flexShrink: 0, paddingTop: safeTop(platform), color: '#fff', position: 'relative', overflow: 'hidden',
        background: 'var(--gb-hero)',
      }}>
        <div style={{ position: 'absolute', right: -50, top: -40, width: 180, height: 180, borderRadius: '50%', background: 'radial-gradient(circle, rgba(120,180,255,0.4), transparent 70%)' }} />
        <div style={{ position: 'relative', padding: '6px 16px 14px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <button onClick={() => setSheet('abandon')} style={glassBtn}>
              <Icon name="x" size={20} color="#fff" />
            </button>
            <div style={{ flex: 1, textAlign: 'center' }}>
              <div style={{ fontSize: 16, fontWeight: 800, letterSpacing: '-0.01em' }}>{TODAY_WORKOUT.name}</div>
              <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.75)' }}>{TODAY_WORKOUT.day} · Week {TODAY_WORKOUT.week}</div>
            </div>
            <div style={{ ...glassBtn, width: 'auto', padding: '0 12px', gap: 6, fontWeight: 800, fontSize: 13 }} className="gb-num">
              <Icon name="clock" size={15} color="#fff" />{fmtClock(elapsed)}
            </div>
          </div>
          {/* progress */}
          <div style={{ marginTop: 14, display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ flex: 1, height: 8, borderRadius: 999, background: 'rgba(255,255,255,0.22)', overflow: 'hidden' }}>
              <div style={{ width: (doneSets / totalSets * 100) + '%', height: '100%', background: 'linear-gradient(90deg, #a5f3d0, #fff)', borderRadius: 999, boxShadow: '0 0 10px rgba(255,255,255,0.6)', transition: 'width .35s' }} />
            </div>
            <span className="gb-num" style={{ fontSize: 12, fontWeight: 800 }}>{doneSets}/{totalSets} sets</span>
          </div>
        </div>
      </div>

      {/* Exercise pager dots */}
      <div style={{ flexShrink: 0, display: 'flex', gap: 6, overflowX: 'auto', padding: '12px 16px 10px', background: 'var(--inv-surface-base)', borderBottom: '1px solid var(--inv-border-card)' }}>
        {exs.map((e, i) => {
          const d = e.sets.every(s => s.done || s.skipped);
          const on = i === cur;
          return (
            <button key={e.id} onClick={() => setCur(i)} style={{
              flexShrink: 0, height: 30, padding: '0 11px', borderRadius: 999, cursor: 'pointer',
              border: `1.5px solid ${on ? 'var(--inv-primary-500)' : d ? 'var(--inv-success-50)' : 'var(--inv-border-card)'}`,
              background: on ? 'var(--inv-primary-500)' : d ? 'var(--inv-success-0)' : 'var(--inv-surface-base)',
              color: on ? '#fff' : d ? 'var(--inv-success-300)' : 'var(--inv-grey-500)',
              font: '700 12px var(--inv-font-sans)', display: 'inline-flex', alignItems: 'center', gap: 5,
            }}>
              {d && !on && <Icon name="check" size={13} />}{i + 1}
            </button>
          );
        })}
        <button onClick={() => setSheet('add')} style={{
          flexShrink: 0, height: 30, padding: '0 12px', borderRadius: 999, cursor: 'pointer',
          border: '1.5px dashed var(--inv-grey-100)', background: 'var(--inv-surface-base)',
          color: 'var(--inv-grey-500)', font: '700 12px var(--inv-font-sans)',
          display: 'inline-flex', alignItems: 'center', gap: 4,
        }}>
          <Icon name="plus" size={14} /> Add
        </button>
      </div>

      {/* Body */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px 16px' }}>
        {/* Exercise card */}
        <div style={{ background: 'var(--inv-surface-base)', border: '1px solid var(--inv-border-card)', borderRadius: 'var(--gb-r-lg)', boxShadow: 'var(--gb-shadow)', overflow: 'hidden' }}>
          <div style={{ padding: 16, borderBottom: '1px solid var(--inv-border-card)' }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--gb-ink)', letterSpacing: '-0.02em' }}>{ex.name}</div>
                <div style={{ display: 'flex', gap: 8, marginTop: 6 }}>
                  <span style={metaPill}>{ex.muscle}</span>
                  <span style={metaPill}>{ex.equipment}</span>
                  <span style={metaPill}>{ex.sets.length} × {ex.sets[ex.sets.length-1].reps} @ {ex.sets[ex.sets.length-1].kg}kg</span>
                </div>
              </div>
              <button onClick={() => setSheet('more')} style={{ width: 36, height: 36, borderRadius: 9, border: '1px solid var(--inv-border-card)', background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
                <Icon name="more" size={20} color="var(--inv-grey-600)" />
              </button>
            </div>
          </div>

          {/* Sets */}
          <div style={{ padding: '6px 0' }}>
            {ex.sets.map((s, si) => {
              const isCurrent = si === curSetIdx;
              const num = si + 1;
              if (s.done) {
                return (
                  <div key={si} style={setRowStyle}>
                    <span style={{ ...setNum, background: 'var(--inv-success-0)', color: 'var(--inv-success-300)' }}>
                      <Icon name="check" size={15} />
                    </span>
                    <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--inv-grey-400)', width: 64 }}>{SET_TYPE_LABEL[s.type]}</span>
                    <span style={{ flex: 1 }} />
                    <div style={{ textAlign: 'right' }}>
                      <span className="gb-num" style={{ fontSize: 15, fontWeight: 700, color: 'var(--inv-grey-700)', whiteSpace: 'nowrap' }}>{s.kg}kg × {s.reps}</span>
                      {s.type === 'working' && e1rm(s.kg, s.reps) && (
                        <div className="gb-num" style={{ fontSize: 11, color: 'var(--inv-grey-400)', whiteSpace: 'nowrap' }}>e1RM {e1rm(s.kg, s.reps)}kg</div>
                      )}
                    </div>
                  </div>
                );
              }
              if (s.skipped) {
                return (
                  <div key={si} style={{ ...setRowStyle, opacity: 0.6 }}>
                    <span style={{ ...setNum, background: 'var(--inv-grey-25)', color: 'var(--inv-grey-400)' }}>{num}</span>
                    <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--inv-grey-400)' }}>Skipped</span>
                  </div>
                );
              }
              if (isCurrent) {
                return (
                  <div key={si} style={{ margin: '6px 12px', padding: 14, borderRadius: 'var(--gb-r-md)', background: 'linear-gradient(180deg, #eff6ff, #e6f0ff)', border: '1.5px solid var(--inv-primary-200)', boxShadow: '0 6px 16px -10px rgba(37,99,235,0.5)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
                      <span style={{ ...setNum, background: 'var(--inv-primary-500)', color: '#fff' }}>{num}</span>
                      <button onClick={() => cycleType(si)} style={{ display: 'inline-flex', alignItems: 'center', gap: 4, height: 26, padding: '0 9px', borderRadius: 7, cursor: 'pointer', border: '1px solid var(--inv-primary-200)', background: 'var(--inv-surface-base)', font: '700 12px var(--inv-font-sans)', color: 'var(--inv-primary-700)' }}>
                        {SET_TYPE_LABEL[s.type]}<Icon name="chevD" size={13} color="var(--inv-primary-500)" />
                      </button>
                      <span style={{ flex: 1 }} />
                      <span className="gb-num" style={{ fontSize: 12, color: 'var(--inv-grey-500)', whiteSpace: 'nowrap' }}>Target {s.kg}kg × {s.reps}</span>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'stretch', gap: 6, marginBottom: 14 }}>
                      <div style={{ flex: 1, textAlign: 'center' }}>
                        <div style={stepLabel}>WEIGHT</div>
                        <Stepper big value={s.kg} unit="kg" step={2.5} onChange={v => editSet(si, 'kg', v)} />
                      </div>
                      <div style={{ width: 1, background: 'var(--inv-primary-100)' }} />
                      <div style={{ flex: 1, textAlign: 'center' }}>
                        <div style={stepLabel}>REPS</div>
                        <Stepper big value={s.reps} step={1} onChange={v => editSet(si, 'reps', v)} />
                      </div>
                    </div>
                    {s.type === 'working' && e1rm(s.kg, s.reps) && (
                      <div className="gb-num" style={{ textAlign: 'center', fontSize: 12, color: 'var(--inv-grey-500)', marginBottom: 10, whiteSpace: 'nowrap' }}>
                        Est. 1RM <b style={{ color: 'var(--inv-grey-800)' }}>{e1rm(s.kg, s.reps)} kg</b> · Epley
                      </div>
                    )}
                    <GbButton full size="lg" icon="check" label="Log set" onClick={() => logSet(si)} />
                  </div>
                );
              }
              return (
                <div key={si} style={setRowStyle}>
                  <span style={{ ...setNum, background: 'var(--inv-grey-25)', color: 'var(--inv-grey-500)' }}>{num}</span>
                  <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--inv-grey-400)', width: 64 }}>{SET_TYPE_LABEL[s.type]}</span>
                  <span style={{ flex: 1 }} />
                  <span className="gb-num" style={{ fontSize: 14, fontWeight: 600, color: 'var(--inv-grey-400)', whiteSpace: 'nowrap' }}>{s.kg}kg × {s.reps}</span>
                </div>
              );
            })}
            <button onClick={addSet} style={{
              margin: '8px 16px 6px', width: 'calc(100% - 32px)', height: 40, borderRadius: 10, cursor: 'pointer',
              border: '1.5px dashed var(--inv-border-field)', background: 'transparent',
              color: 'var(--inv-grey-600)', font: '600 13px var(--inv-font-sans)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
            }}>
              <Icon name="plus" size={16} /> Add set
            </button>
          </div>
        </div>

        <p style={{ textAlign: 'center', fontSize: 12, color: 'var(--inv-grey-400)', marginTop: 14 }}>
          Logged values save to your session automatically.
        </p>
      </div>

      {/* Rest timer bar */}
      {rest && (
        <div style={{ flexShrink: 0, padding: '11px 16px', background: 'var(--gb-hero-deep)', display: 'flex', alignItems: 'center', gap: 14, boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.1)' }}>
          <Ring value={rest.total - rest.remaining} total={rest.total} size={44} stroke={4.5} gradient={['#6ee7b7', '#34d399']} track="rgba(255,255,255,0.16)">
            <span className="gb-num" style={{ fontSize: 12, fontWeight: 800, color: '#fff' }}>{rest.remaining}</span>
          </Ring>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: '#fff' }}>Rest · {fmtClock(rest.remaining)}</div>
            <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.6)' }}>Next: set ready when you are</div>
          </div>
          <button onClick={() => setRest(r => ({ ...r, remaining: r.remaining + 15, total: r.total + 15 }))} style={restBtn}>+15s</button>
          <button onClick={() => setRest(null)} style={{ ...restBtn, background: 'rgba(255,255,255,0.16)' }}>Skip</button>
        </div>
      )}

      {/* Action bar */}
      <div style={{ flexShrink: 0, padding: `12px 16px ${bottomInset(platform) + 12}px`, background: 'var(--inv-surface-base)', borderTop: '1px solid var(--inv-border-card)', display: 'flex', gap: 10 }}>
        <GbButton outlined severity="secondary" icon="chevL" label="" onClick={() => setCur(Math.max(0, cur - 1))}
          disabled={cur === 0} style={{ width: 52, padding: 0 }} />
        {allDone ? (
          <GbButton full size="md" icon="flag" label="Finish workout" onClick={onComplete} style={{ flex: 1 }} />
        ) : exDone && cur < exs.length - 1 ? (
          <GbButton full size="md" iconRight="arrowR" label="Next exercise" onClick={() => setCur(cur + 1)} style={{ flex: 1 }} />
        ) : cur < exs.length - 1 ? (
          <GbButton full size="md" severity="secondary" outlined iconRight="chevR" label="Next exercise" onClick={() => setCur(cur + 1)} style={{ flex: 1 }} />
        ) : (
          <GbButton full size="md" icon="flag" label="Finish workout" onClick={onComplete} style={{ flex: 1 }} />
        )}
      </div>

      {/* More menu sheet */}
      <BottomSheet open={sheet === 'more'} onClose={() => setSheet(null)}>
        <div style={{ padding: '6px 12px 22px' }}>
          <div style={{ fontSize: 16, fontWeight: 800, color: 'var(--inv-grey-900)', padding: '4px 8px 10px' }}>{ex.name}</div>
          <SheetAction icon="swap" label="Substitute exercise" sub="Swap for an equivalent movement" onClick={() => setSheet('sub')} />
          <SheetAction icon="skip" label="Skip exercise" disabled={exHasLogged}
            sub={exHasLogged ? 'Has logged sets \u2014 can\u2019t skip' : 'Mark remaining sets as skipped'}
            onClick={skipExercise} />
        </div>
      </BottomSheet>

      {/* Substitute sheet */}
      <BottomSheet open={sheet === 'sub'} onClose={() => setSheet(null)}>
        <div style={{ padding: '6px 16px 22px' }}>
          <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--inv-grey-900)' }}>Substitute</div>
          <div style={{ fontSize: 13, color: 'var(--inv-grey-500)', marginTop: 2, marginBottom: 14 }}>Replace {ex.name} for this session.</div>
          {(SUBSTITUTES[ex.id] || SUBSTITUTES.e1).map(o => (
            <button key={o.name} onClick={() => substitute(o.name, o.equipment)} style={{
              width: '100%', textAlign: 'left', cursor: 'pointer', marginBottom: 8,
              background: 'var(--inv-surface-base)', border: '1.5px solid var(--inv-border-card)', borderRadius: 12, padding: 13,
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{ width: 38, height: 38, borderRadius: 10, background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="dumbbell" size={20} color="var(--inv-grey-500)" />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--inv-grey-900)' }}>{o.name}</div>
                <div style={{ fontSize: 12, color: 'var(--inv-grey-500)' }}>{o.muscle} · {o.equipment}</div>
              </div>
              <Icon name="chevR" size={18} color="var(--inv-grey-300)" />
            </button>
          ))}
        </div>
      </BottomSheet>

      {/* Add exercise sheet */}
      <BottomSheet open={sheet === 'add'} onClose={() => setSheet(null)} height="78%">
        <div style={{ padding: '6px 16px 0', display: 'flex', flexDirection: 'column', minHeight: 0, flex: 1 }}>
          <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--inv-grey-900)' }}>Add exercise</div>
          <div style={{ fontSize: 13, color: 'var(--inv-grey-500)', marginTop: 2, marginBottom: 12 }}>Add a movement to this session.</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, height: 44, padding: '0 12px', borderRadius: 10, background: 'var(--inv-grey-0)', border: '1px solid var(--inv-border-field)', marginBottom: 10, flexShrink: 0 }}>
            <Icon name="search" size={18} color="var(--inv-grey-400)" />
            <span style={{ fontSize: 14, color: 'var(--inv-grey-400)' }}>Search exercises…</span>
          </div>
          <div style={{ display: 'flex', gap: 6, overflowX: 'auto', marginBottom: 12, flexShrink: 0 }}>
            {['All', ...MUSCLE_GROUPS].map(g => {
              const on = muscleFilter === g;
              return (
                <button key={g} onClick={() => setMuscleFilter(g)} style={{
                  flexShrink: 0, height: 30, padding: '0 13px', borderRadius: 999, cursor: 'pointer',
                  border: `1.5px solid ${on ? 'var(--inv-primary-500)' : 'var(--inv-border-card)'}`,
                  background: on ? 'var(--inv-primary-500)' : 'var(--inv-surface-base)',
                  color: on ? '#fff' : 'var(--inv-grey-600)', font: '600 12.5px var(--inv-font-sans)',
                }}>{g}</button>
              );
            })}
          </div>
          <div style={{ flex: 1, overflowY: 'auto', paddingBottom: bottomInset(platform) + 12 }}>
            {EXERCISE_LIBRARY.filter(o => muscleFilter === 'All' || o.muscle === muscleFilter).map(o => (
              <button key={o.name} onClick={() => addExercise(o)} style={{
                width: '100%', textAlign: 'left', cursor: 'pointer', marginBottom: 8,
                background: 'var(--inv-surface-base)', border: '1.5px solid var(--inv-border-card)', borderRadius: 12, padding: 12,
                display: 'flex', alignItems: 'center', gap: 12,
              }}>
                <div style={{ width: 38, height: 38, borderRadius: 10, background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name="dumbbell" size={20} color="var(--inv-grey-500)" />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--inv-grey-900)' }}>{o.name}</div>
                  <div style={{ fontSize: 12, color: 'var(--inv-grey-500)' }}>{o.muscle} · {o.equipment}</div>
                </div>
                <div style={{ width: 30, height: 30, borderRadius: 8, background: 'var(--inv-primary-0)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name="plus" size={18} color="var(--inv-primary-600)" />
                </div>
              </button>
            ))}
          </div>
        </div>
      </BottomSheet>

      {/* Abandon sheet */}
      <BottomSheet open={sheet === 'abandon'} onClose={() => setSheet(null)}>
        <div style={{ padding: '10px 20px 24px' }}>
          <div style={{ width: 48, height: 48, borderRadius: 14, background: 'var(--inv-error-0)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
            <Icon name="flag" size={24} color="var(--inv-error-100)" />
          </div>
          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--inv-grey-900)' }}>Abandon session?</div>
          <div style={{ fontSize: 14, color: 'var(--inv-grey-500)', marginTop: 4, marginBottom: 18, lineHeight: 1.5 }}>
            You've logged {doneSets} of {totalSets} sets. The session will be saved as abandoned and you can't resume it.
          </div>
          <GbButton full severity="danger" label="Abandon session" onClick={onAbandon} />
          <div style={{ height: 10 }} />
          <GbButton full severity="secondary" outlined label="Keep training" onClick={() => setSheet(null)} />
        </div>
      </BottomSheet>
    </div>
  );
}

function SheetAction({ icon, label, sub, onClick, disabled }) {
  return (
    <button onClick={disabled ? undefined : onClick} disabled={disabled} style={{
      width: '100%', textAlign: 'left', cursor: disabled ? 'default' : 'pointer', background: 'none', border: 'none',
      borderRadius: 12, padding: '12px 8px', display: 'flex', alignItems: 'center', gap: 14, opacity: disabled ? 0.5 : 1,
    }}>
      <div style={{ width: 42, height: 42, borderRadius: 11, background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon name={icon} size={21} color="var(--inv-grey-700)" />
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--inv-grey-900)' }}>{label}</div>
        <div style={{ fontSize: 12, color: 'var(--inv-grey-500)' }}>{sub}</div>
      </div>
      <Icon name="chevR" size={18} color="var(--inv-grey-300)" />
    </button>
  );
}

const glassBtn = { width: 40, height: 40, borderRadius: 999, border: '1px solid rgba(255,255,255,0.25)', background: 'rgba(255,255,255,0.16)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', color: '#fff' };
const metaPill = { fontSize: 11, fontWeight: 600, color: 'var(--inv-grey-600)', background: 'var(--inv-grey-0)', border: '1px solid var(--inv-border-card)', borderRadius: 7, padding: '3px 8px', whiteSpace: 'nowrap' };
const setRowStyle = { display: 'flex', alignItems: 'center', gap: 12, padding: '10px 16px' };
const setNum = { width: 26, height: 26, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, fontWeight: 800, flexShrink: 0 };
const stepLabel = { fontSize: 10, fontWeight: 700, letterSpacing: '0.08em', color: 'var(--inv-grey-400)', marginBottom: 8 };
const restBtn = { height: 36, padding: '0 14px', borderRadius: 10, border: 'none', cursor: 'pointer', background: 'rgba(255,255,255,0.10)', color: '#fff', font: '700 13px var(--inv-font-sans)' };

Object.assign(window, { ActiveSessionScreen });
