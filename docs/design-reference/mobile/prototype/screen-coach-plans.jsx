// GymBro Mobile — Coach: Plans list, Plan Builder (immutable versioning),
// Assign (version pinning + visibility modes + hide flags). Mirrors the
// plan/assignment lifecycle in BUSINESS_RULES.

const SET_TYPE_STYLE = {
  warmup:  ['var(--inv-warning-0)', 'var(--inv-warning-300)', 'Warm-up'],
  working: ['var(--inv-primary-0)', 'var(--inv-primary-700)', 'Working'],
  drop:    ['var(--inv-sky-0)', 'var(--inv-sky-300)', 'Drop'],
  amrap:   ['var(--inv-success-0)', 'var(--inv-success-300)', 'AMRAP'],
};
function SetTypeChip({ type }) {
  const [bg, fg, label] = SET_TYPE_STYLE[type] || SET_TYPE_STYLE.working;
  return <span style={{ fontSize: 10.5, fontWeight: 700, borderRadius: 5, padding: '2px 7px', background: bg, color: fg }}>{label}</span>;
}

// ── Plans list (tab) ──────────────────────────────────────────
function PlansScreen({ platform, onOpenPlan, onAssign, onNew }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--inv-grey-0)' }}>
      <div style={{ flexShrink: 0, paddingTop: safeTop(platform), background: 'var(--inv-surface-base)', borderBottom: '1px solid var(--inv-border-card)' }}>
        <div style={{ padding: '8px 18px 12px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12, color: 'var(--inv-grey-500)' }}>{COACH.workspace}</div>
            <div style={{ fontSize: 19, fontWeight: 800, color: 'var(--inv-grey-900)', letterSpacing: '-0.01em' }}>Plans</div>
          </div>
          <button onClick={onNew} style={{ height: 38, padding: '0 14px', borderRadius: 10, border: 'none', cursor: 'pointer', background: 'var(--inv-primary-500)', color: '#fff', font: '700 13px var(--inv-font-sans)', display: 'inline-flex', alignItems: 'center', gap: 6, boxShadow: '0 2px 8px rgba(37,99,235,0.28)' }}>
            <Icon name="plus" size={17} /> New
          </button>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 18px 90px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {COACH_PLANS.map(p => (
          <div key={p.id} style={{ background: 'var(--inv-surface-base)', border: '1px solid var(--inv-border-card)', borderRadius: 14, boxShadow: 'var(--inv-shadow-card)', overflow: 'hidden', opacity: p.archived ? 0.7 : 1 }}>
            <button onClick={() => onOpenPlan(p)} style={{ width: '100%', textAlign: 'left', cursor: 'pointer', background: 'none', border: 'none', padding: 14, display: 'block' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: 16, fontWeight: 800, color: 'var(--inv-grey-900)' }}>{p.name}</span>
                <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--inv-grey-600)', background: 'var(--inv-grey-25)', borderRadius: 5, padding: '2px 7px' }}>v{p.version}</span>
                {p.archived && <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--inv-grey-500)', background: 'var(--inv-grey-25)', borderRadius: 5, padding: '2px 7px', display: 'inline-flex', alignItems: 'center', gap: 4 }}><Icon name="archive" size={11} />Archived</span>}
              </div>
              <div style={{ display: 'flex', gap: 12, marginTop: 7, fontSize: 12.5, color: 'var(--inv-grey-500)' }}>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><Icon name="layers" size={13} />{p.workouts} workouts</span>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><Icon name="calendar" size={13} />{p.daysPerWeek}×/wk</span>
                <span>{p.durationWeeks} wks</span>
              </div>
            </button>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '0 14px 12px' }}>
              <span style={{ flex: 1, fontSize: 12, color: 'var(--inv-grey-400)' }}>
                {p.assigned > 0 ? `Assigned to ${p.assigned} client${p.assigned > 1 ? 's' : ''}` : 'Not assigned'} · updated {p.updated}
              </span>
              {!p.archived && <GbButton size="sm" severity="secondary" outlined icon="userPlus" label="Assign" onClick={() => onAssign(p)} />}
            </div>
          </div>
        ))}
        <p style={{ textAlign: 'center', fontSize: 12, color: 'var(--inv-grey-400)', marginTop: 4, lineHeight: 1.5 }}>
          Editing a plan saves an immutable new version. Existing assignments stay pinned until you apply the latest.
        </p>
      </div>
    </div>
  );
}

// ── Plan builder (full screen) ────────────────────────────────
function PlanBuilderScreen({ platform, plan, onBack, isNew }) {
  const [name, setName] = React.useState(isNew ? 'New plan' : PLAN_DETAIL.name);
  const [workouts, setWorkouts] = React.useState(() => isNew
    ? [{ id: 'w' + Date.now(), name: 'Workout 1', exercises: [] }]
    : PLAN_DETAIL.workouts.map(w => ({ ...w, exercises: w.exercises.map(e => ({ ...e, sets: [...e.sets] })) })));
  const [open, setOpen] = React.useState({ 0: true });
  const [saved, setSaved] = React.useState(false);
  const nextVersion = (isNew ? 1 : PLAN_DETAIL.version + 1);

  function addSet(wi, ei) {
    setWorkouts(prev => prev.map((w, i) => i !== wi ? w : {
      ...w, exercises: w.exercises.map((e, j) => j !== ei ? e : {
        ...e, sets: [...e.sets, { ...(e.sets[e.sets.length - 1] || { type: 'working', reps: 10, kg: 20, rpe: 8, rest: 90 }) }],
      }),
    }));
  }
  function addWorkout() {
    setWorkouts(prev => [...prev, { id: 'w' + Date.now(), name: 'Workout ' + (prev.length + 1), exercises: [] }]);
    setOpen(o => ({ ...o, [workouts.length]: true }));
  }

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--inv-grey-0)' }}>
      <div style={{ flexShrink: 0, paddingTop: safeTop(platform), background: 'var(--inv-surface-base)', borderBottom: '1px solid var(--inv-border-card)' }}>
        <div style={{ padding: '8px 12px 12px', display: 'flex', alignItems: 'center', gap: 8 }}>
          <button onClick={onBack} style={{ width: 40, height: 40, borderRadius: '50%', border: 'none', background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name="chevL" size={20} color="var(--inv-grey-700)" />
          </button>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 800, color: 'var(--inv-grey-900)' }}>{isNew ? 'New plan' : 'Edit plan'}</div>
            <div style={{ fontSize: 11.5, color: 'var(--inv-grey-500)' }}>Saving creates v{nextVersion}</div>
          </div>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 18px 18px' }}>
        {/* Meta */}
        <div style={{ marginBottom: 14 }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--inv-grey-700)', marginBottom: 6 }}>Plan name</div>
          <input value={name} onChange={e => setName(e.target.value)} style={{
            width: '100%', height: 48, padding: '0 14px', borderRadius: 8, border: '1.5px solid var(--inv-border-field)',
            font: '700 16px var(--inv-font-sans)', color: 'var(--inv-grey-900)', outline: 'none', background: 'var(--inv-surface-base)',
          }} />
          <div style={{ display: 'flex', gap: 10, marginTop: 10 }}>
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 8, height: 44, padding: '0 12px', borderRadius: 8, border: '1px solid var(--inv-border-card)', background: 'var(--inv-surface-base)' }}>
              <Icon name="calendar" size={16} color="var(--inv-grey-400)" />
              <span style={{ fontSize: 13, color: 'var(--inv-grey-700)' }}>8 weeks</span>
            </div>
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 8, height: 44, padding: '0 12px', borderRadius: 8, border: '1px solid var(--inv-border-card)', background: 'var(--inv-surface-base)' }}>
              <Icon name="history" size={16} color="var(--inv-grey-400)" />
              <span style={{ fontSize: 13, color: 'var(--inv-grey-700)' }}>{workouts.length} days/wk</span>
            </div>
          </div>
        </div>

        {/* Workouts */}
        {workouts.map((w, wi) => {
          const isOpen = open[wi];
          return (
            <div key={w.id} style={{ background: 'var(--inv-surface-base)', border: '1px solid var(--inv-border-card)', borderRadius: 14, boxShadow: 'var(--inv-shadow-card)', marginBottom: 10, overflow: 'hidden' }}>
              <button onClick={() => setOpen(o => ({ ...o, [wi]: !o[wi] }))} style={{ width: '100%', cursor: 'pointer', background: 'none', border: 'none', padding: 14, display: 'flex', alignItems: 'center', gap: 10 }}>
                <Icon name="chevR" size={16} color="var(--inv-grey-400)" style={{ transform: isOpen ? 'rotate(90deg)' : 'none', transition: 'transform .2s' }} />
                <span style={{ flex: 1, textAlign: 'left', fontSize: 15, fontWeight: 800, color: 'var(--inv-grey-900)' }}>{w.name}</span>
                <span style={{ fontSize: 12, color: 'var(--inv-grey-400)' }}>{w.exercises.length} exercises</span>
              </button>
              {isOpen && (
                <div style={{ padding: '0 14px 14px' }}>
                  {w.exercises.map((e, ei) => (
                    <div key={e.id} style={{ border: '1px solid var(--inv-border-card)', borderRadius: 12, padding: 12, marginBottom: 8 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--inv-grey-900)' }}>{e.name}</div>
                          <div style={{ fontSize: 11.5, color: 'var(--inv-grey-400)' }}>{e.muscle} · {e.sets.length} sets</div>
                        </div>
                        <Icon name="more" size={18} color="var(--inv-grey-400)" />
                      </div>
                      {e.sets.map((s, si) => (
                        <div key={si} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 0', borderTop: si > 0 ? '1px solid var(--inv-grey-25)' : 'none' }}>
                          <span style={{ width: 18, fontSize: 12, fontWeight: 700, color: 'var(--inv-grey-400)' }}>{si + 1}</span>
                          <SetTypeChip type={s.type} />
                          <span style={{ flex: 1 }} />
                          <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--inv-grey-700)' }}>{s.kg ? s.kg + 'kg' : '—'} × {s.reps}</span>
                          {s.rpe && <span style={{ fontSize: 11, color: 'var(--inv-grey-400)' }}>@{s.rpe}</span>}
                          <span style={{ fontSize: 11, color: 'var(--inv-grey-400)' }}>{s.rest}s</span>
                        </div>
                      ))}
                      <button onClick={() => addSet(wi, ei)} style={{ width: '100%', marginTop: 8, height: 34, borderRadius: 8, cursor: 'pointer', border: '1.5px dashed var(--inv-border-field)', background: 'transparent', color: 'var(--inv-grey-600)', font: '600 12px var(--inv-font-sans)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5 }}>
                        <Icon name="plus" size={14} /> Add set
                      </button>
                    </div>
                  ))}
                  <button style={{ width: '100%', height: 40, borderRadius: 10, cursor: 'pointer', border: '1.5px dashed var(--inv-primary-200)', background: 'var(--inv-primary-0)', color: 'var(--inv-primary-700)', font: '700 13px var(--inv-font-sans)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
                    <Icon name="plus" size={15} /> Add exercise
                  </button>
                </div>
              )}
            </div>
          );
        })}

        <button onClick={addWorkout} style={{ width: '100%', height: 46, borderRadius: 12, cursor: 'pointer', border: '1.5px dashed var(--inv-border-field)', background: 'transparent', color: 'var(--inv-grey-600)', font: '700 14px var(--inv-font-sans)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
          <Icon name="plus" size={17} /> Add workout
        </button>
      </div>

      <div style={{ flexShrink: 0, padding: `12px 16px ${bottomInset(platform) + 12}px`, background: 'var(--inv-surface-base)', borderTop: '1px solid var(--inv-border-card)' }}>
        <GbButton full size="md" icon="check" label={`Save as version ${nextVersion}`} onClick={() => setSaved(true)} />
      </div>

      <BottomSheet open={saved} onClose={() => setSaved(false)}>
        <div style={{ padding: '10px 20px 24px' }}>
          <div style={{ width: 48, height: 48, borderRadius: 14, background: 'var(--inv-success-0)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
            <Icon name="check" size={24} color="var(--inv-success-300)" strokeWidth={2.6} />
          </div>
          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--inv-grey-900)' }}>Saved as version {nextVersion}</div>
          <div style={{ fontSize: 14, color: 'var(--inv-grey-500)', marginTop: 4, marginBottom: 18, lineHeight: 1.5 }}>
            Older versions are kept as history. Existing assignments stay pinned to their version until you apply the latest.
          </div>
          <GbButton full label="Done" onClick={onBack} />
        </div>
      </BottomSheet>
    </div>
  );
}

// ── Assign (full screen) ──────────────────────────────────────
function AssignScreen({ platform, plan, onBack }) {
  const [clientId, setClientId] = React.useState(null);
  const [freq, setFreq] = React.useState(4);
  const [vis, setVis] = React.useState('Full');
  const [flags, setFlags] = React.useState({ hideSetsReps: false, hideExercises: false, hideFutureWorkouts: false, disableTraineeEditing: false });
  const [done, setDone] = React.useState(false);
  const p = plan || COACH_PLANS[0];
  const client = CLIENTS.find(c => c.id === clientId);

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--inv-grey-0)' }}>
      <div style={{ flexShrink: 0, paddingTop: safeTop(platform), background: 'var(--inv-surface-base)', borderBottom: '1px solid var(--inv-border-card)' }}>
        <div style={{ padding: '8px 12px 12px', display: 'flex', alignItems: 'center', gap: 8 }}>
          <button onClick={onBack} style={{ width: 40, height: 40, borderRadius: '50%', border: 'none', background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name="chevL" size={20} color="var(--inv-grey-700)" />
          </button>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 800, color: 'var(--inv-grey-900)' }}>Assign plan</div>
            <div style={{ fontSize: 11.5, color: 'var(--inv-grey-500)' }}>{p.name} · pins v{p.version}</div>
          </div>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 18px 18px' }}>
        {/* Client */}
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--inv-grey-900)', marginBottom: 8 }}>Client</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 18 }}>
          {CLIENTS.map(c => {
            const on = clientId === c.id;
            return (
              <button key={c.id} onClick={() => setClientId(c.id)} style={{
                display: 'flex', alignItems: 'center', gap: 12, padding: 11, cursor: 'pointer', textAlign: 'left',
                background: on ? 'var(--inv-primary-0)' : 'var(--inv-surface-base)',
                border: `1.5px solid ${on ? 'var(--inv-primary-300)' : 'var(--inv-border-card)'}`, borderRadius: 12,
              }}>
                <div style={{ width: 38, height: 38, borderRadius: '50%', background: 'var(--inv-primary-500)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 15 }}>{c.initial}</div>
                <span style={{ flex: 1, fontSize: 14, fontWeight: 700, color: 'var(--inv-grey-900)' }}>{c.name}</span>
                <span style={{ width: 22, height: 22, borderRadius: '50%', border: `2px solid ${on ? 'var(--inv-primary-500)' : 'var(--inv-grey-50)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  {on && <span style={{ width: 11, height: 11, borderRadius: '50%', background: 'var(--inv-primary-500)' }} />}
                </span>
              </button>
            );
          })}
        </div>

        {/* Schedule */}
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--inv-grey-900)', marginBottom: 8 }}>Schedule</div>
        <div style={{ background: 'var(--inv-surface-base)', border: '1px solid var(--inv-border-card)', borderRadius: 14, padding: 14, marginBottom: 18, boxShadow: 'var(--inv-shadow-card)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, paddingBottom: 12, borderBottom: '1px solid var(--inv-grey-25)' }}>
            <Icon name="calendar" size={18} color="var(--inv-grey-500)" />
            <span style={{ flex: 1, fontSize: 14, color: 'var(--inv-grey-900)', fontWeight: 600 }}>Start date</span>
            <span style={{ fontSize: 14, color: 'var(--inv-grey-600)' }}>Today</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, paddingTop: 12 }}>
            <Icon name="history" size={18} color="var(--inv-grey-500)" />
            <span style={{ flex: 1, fontSize: 14, color: 'var(--inv-grey-900)', fontWeight: 600 }}>Days per week</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <button onClick={() => setFreq(Math.max(1, freq - 1))} style={miniStep}><Icon name="minus" size={16} color="var(--inv-grey-700)" /></button>
              <span style={{ minWidth: 18, textAlign: 'center', fontSize: 17, fontWeight: 800, color: 'var(--inv-grey-900)' }}>{freq}</span>
              <button onClick={() => setFreq(Math.min(7, freq + 1))} style={miniStep}><Icon name="plus" size={16} color="var(--inv-grey-700)" /></button>
            </div>
          </div>
        </div>

        {/* Visibility */}
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--inv-grey-900)', marginBottom: 8 }}>Visibility</div>
        <div style={{ display: 'flex', gap: 6, marginBottom: 8 }}>
          {VISIBILITY_MODES.map(m => {
            const on = vis === m.id;
            return (
              <button key={m.id} onClick={() => setVis(m.id)} style={{
                flex: 1, height: 40, borderRadius: 10, cursor: 'pointer', font: '700 13px var(--inv-font-sans)',
                border: `1.5px solid ${on ? 'var(--inv-primary-500)' : 'var(--inv-border-card)'}`,
                background: on ? 'var(--inv-primary-500)' : 'var(--inv-surface-base)', color: on ? '#fff' : 'var(--inv-grey-600)',
              }}>{m.label}</button>
            );
          })}
        </div>
        <p style={{ fontSize: 12.5, color: 'var(--inv-grey-500)', margin: '0 0 14px', lineHeight: 1.5 }}>{VISIBILITY_MODES.find(m => m.id === vis).desc}</p>

        {/* Hide flags (Guided only) */}
        {vis === 'Guided' && (
          <div style={{ background: 'var(--inv-surface-base)', border: '1px solid var(--inv-border-card)', borderRadius: 14, overflow: 'hidden', marginBottom: 16, boxShadow: 'var(--inv-shadow-card)' }}>
            {HIDE_FLAGS.map((f, i) => (
              <div key={f.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 14px', borderBottom: i < HIDE_FLAGS.length - 1 ? '1px solid var(--inv-border-card)' : 'none' }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--inv-grey-900)' }}>{f.label}</div>
                  <div style={{ fontSize: 12, color: 'var(--inv-grey-400)', lineHeight: 1.4 }}>{f.desc}</div>
                </div>
                <GbSwitch on={flags[f.id]} onChange={v => setFlags(p => ({ ...p, [f.id]: v }))} platform={platform} />
              </div>
            ))}
          </div>
        )}
      </div>

      <div style={{ flexShrink: 0, padding: `12px 16px ${bottomInset(platform) + 12}px`, background: 'var(--inv-surface-base)', borderTop: '1px solid var(--inv-border-card)' }}>
        <GbButton full size="md" icon="check" label="Assign plan" disabled={!clientId} onClick={() => setDone(true)} />
      </div>

      <BottomSheet open={done} onClose={() => setDone(false)}>
        <div style={{ padding: '10px 20px 24px' }}>
          <div style={{ width: 48, height: 48, borderRadius: 14, background: 'var(--inv-success-0)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
            <Icon name="check" size={24} color="var(--inv-success-300)" strokeWidth={2.6} />
          </div>
          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--inv-grey-900)' }}>Plan assigned</div>
          <div style={{ fontSize: 14, color: 'var(--inv-grey-500)', marginTop: 4, marginBottom: 18, lineHeight: 1.5 }}>
            {p.name} (v{p.version}) assigned to {client ? client.name : 'client'} · {vis} · {freq}×/week. Pinned to v{p.version} until you apply the latest.
          </div>
          <GbButton full label="Back to client" onClick={onBack} />
        </div>
      </BottomSheet>
    </div>
  );
}

const miniStep = { width: 36, height: 36, borderRadius: 9, border: '1.5px solid var(--inv-border-card)', background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' };

Object.assign(window, { PlansScreen, PlanBuilderScreen, AssignScreen, SetTypeChip });
