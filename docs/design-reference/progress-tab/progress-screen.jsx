// GymBro Progress — "Graphite" screen. Same IA, cards, flow, copy.
// Typography-led, near-monochrome, instrument-grade. Color is reserved
// for meaning (improvement / attention). Hierarchy through contrast.

const { useState } = React;

const LIFTS = [
  { name: 'Bench Press', e1rm: 84,  dir: 'up',   delta: '+4.2 kg', data: [78, 79, 80, 80.5, 81.5, 82, 83, 84] },
  { name: 'Squat',       e1rm: 130, dir: 'flat', delta: 'Flat 4×', stall: true, data: [128, 129, 130, 129.5, 130, 130, 129.5, 130] },
  { name: 'Deadlift',    e1rm: 153, dir: 'up',   delta: '+6.0 kg', data: [144, 146, 147, 149, 150, 151, 152, 153] },
];
const WEEKS = [
  [2,0,2,0,3,0,0],[0,2,0,2,0,2,0],[3,0,2,0,2,0,0],[0,2,0,0,0,0,0],
  [0,0,0,0,0,0,0],[2,0,2,0,0,0,0],[2,0,2,0,3,0,0],[0,2,0,2,0,2,0],
  [3,0,3,0,2,0,0],[2,0,2,0,3,0,2],[0,3,0,2,0,3,0],[3,0,2,0,null,null,null],
];

// ── App chrome ────────────────────────────────────────────────
const STUB = {
  plan:    { title: 'Plan', icon: 'calendar', body: 'Your assigned plan and upcoming workouts live in the Plan tab.' },
  log:     { title: 'Workout Log', icon: 'history', body: 'Your full session history and logging live in the Log tab.' },
  profile: { title: 'Profile', icon: 'user', body: 'Account, units and settings live in the Profile tab.' },
  start:   { title: 'Start a workout', icon: 'plus', body: 'Starting a session opens the live workout flow.' },
  notif:   { title: 'Notifications', icon: 'bell', body: 'PRs, coach notes and reminders appear here.' },
};

function Header({ sub, onNav = () => {} }) {
  return (
    <div style={{ flexShrink: 0, paddingTop: 50, background: 'var(--card)', position: 'relative', zIndex: 4, borderBottom: '1px solid var(--line)' }}>
      <div style={{ padding: '11px 18px 15px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <BrandMark size={34} radius={10} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 23, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.035em', lineHeight: 1 }}>Progress</div>
          {sub && <div className="gb-label" style={{ marginTop: 4 }}>{sub}</div>}
        </div>
        <button onClick={() => onNav('stub', STUB.notif)} style={{
          position: 'relative', width: 40, height: 40, borderRadius: 11, flexShrink: 0,
          border: '1px solid var(--line)', background: 'var(--card)', boxShadow: 'var(--sh)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        }}>
          <Icon name="bell" size={19} color="var(--ink2)" />
          <span style={{ position: 'absolute', top: 9, right: 10, width: 6, height: 6, borderRadius: '50%', background: 'var(--brand)', border: '1.5px solid var(--card)' }} />
        </button>
      </div>
    </div>
  );
}

const NAV = [
  { id: 'log', label: 'Log', icon: 'history' },
  { id: 'plan', label: 'Plan', icon: 'calendar' },
  { id: 'start', label: 'Start', icon: 'plus' },
  { id: 'progress', label: 'Progress', icon: 'chart' },
  { id: 'profile', label: 'Profile', icon: 'user' },
];
function BottomNav({ active = 'progress', onNav = () => {} }) {
  return (
    <div style={{ flexShrink: 0, position: 'relative', paddingBottom: 26, paddingTop: 8, background: 'var(--card)', borderTop: '1px solid var(--line)' }}>
      <div style={{ display: 'flex', alignItems: 'center', height: 52 }}>
        {NAV.map(t => {
          if (t.id === 'start') {
            return (
              <button key={t.id} onClick={() => onNav('stub', STUB.start)} style={{ flex: 1, border: 'none', background: 'none', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                <div style={{ width: 38, height: 38, borderRadius: 11, background: 'var(--brand-grad)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 12px -4px rgba(37,99,235,0.5), inset 0 1px 0 rgba(255,255,255,0.25)' }}>
                  <Icon name="plus" size={21} color="#fff" strokeWidth={2.4} />
                </div>
                <span style={{ fontSize: 10, fontWeight: 700, color: 'var(--brand)', letterSpacing: '0.01em' }}>Start</span>
              </button>
            );
          }
          const on = active === t.id;
          return (
            <button key={t.id} onClick={() => onNav(t.id === 'progress' ? 'home' : 'stub', t.id === 'progress' ? null : STUB[t.id])} style={{ flex: 1, border: 'none', background: 'none', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
              <div style={{ height: 38, display: 'flex', alignItems: 'center' }}>
                <Icon name={t.icon} size={23} strokeWidth={on ? 2.2 : 1.8} color={on ? 'var(--brand)' : 'var(--ink4)'} />
              </div>
              <span style={{ fontSize: 10, fontWeight: on ? 700 : 500, color: on ? 'var(--brand)' : 'var(--ink3)', letterSpacing: '0.01em' }}>{t.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Section 1 — This-week status · GRAPHITE HERO PANEL
// ─────────────────────────────────────────────────────────────
function StatusSection({ noplan, onNav = () => {} }) {
  return (
    <div onClick={() => onNav('weekly')} style={{ flexShrink: 0, background: 'var(--hero-bg)', borderRadius: 18, padding: '22px 22px 24px', color: 'var(--hero-fg)', boxShadow: 'var(--hero-shadow)', cursor: 'pointer' }}>
      <div className="gb-label" style={{ color: 'var(--hero-mut)' }}>This week</div>
      <div style={{ fontSize: 20, fontWeight: 600, lineHeight: 1.35, marginTop: 12, letterSpacing: '-0.015em', textWrap: 'pretty' }}>
        {noplan
          ? <>You’ve trained <span style={{ color: 'var(--hero-pos)', fontWeight: 700 }}>twice this week</span> — bench &amp; deadlift climbing.</>
          : <>Bench &amp; deadlift <span style={{ color: 'var(--hero-pos)', fontWeight: 700 }}>trending up</span> · 3 of 4 this week.</>}
      </div>

      <div style={{ height: 1, background: 'var(--hero-line)', margin: '18px 0' }} />

      {noplan ? (
        <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
          <div className="gb-num" style={{ fontSize: 48, fontWeight: 800, lineHeight: 0.86, flexShrink: 0 }}>2</div>
          <div style={{ flex: 1 }}>
            <div className="gb-label" style={{ color: 'var(--hero-mut)' }}>Sessions this week</div>
            <div style={{ fontSize: 12.5, color: 'var(--hero-mut)', marginTop: 6, lineHeight: 1.45 }}>Get a plan assigned to track a weekly goal — your training still counts.</div>
          </div>
        </div>
      ) : (
        <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
          <Ring value={3} total={4} size={86} stroke={7} color="var(--hero-ring)" track="var(--hero-track)">
            <div style={{ textAlign: 'center', lineHeight: 1 }}>
              <span className="gb-num" style={{ fontSize: 30, fontWeight: 800 }}>3</span>
              <span className="gb-num" style={{ fontSize: 16, fontWeight: 700, color: 'var(--hero-mut)' }}>/4</span>
            </div>
          </Ring>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 700, letterSpacing: '-0.01em' }}>1 session to your goal</div>
            <div className="gb-label" style={{ color: 'var(--hero-mut)', marginTop: 7, letterSpacing: '0.08em' }}>2 days left · rest days count</div>
          </div>
        </div>
      )}
    </div>
  );
}

function LinkMore({ label, onClick }) {
  return <span onClick={onClick} className="gb-mono" style={{ fontSize: 10.5, fontWeight: 600, color: 'var(--brand)', display: 'inline-flex', alignItems: 'center', gap: 2, whiteSpace: 'nowrap', textTransform: 'uppercase', letterSpacing: '0.06em', cursor: 'pointer' }}>{label} <Icon name="chevR" size={12} color="var(--brand)" strokeWidth={2.2} /></span>;
}

// ─────────────────────────────────────────────────────────────
// Section 2 — Strength progress
// ─────────────────────────────────────────────────────────────
function StrengthSection({ fewpoints, onNav = () => {} }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      <SectionTitle right={<LinkMore label="All lifts" onClick={() => onNav('strength')} />}>Strength</SectionTitle>
      <Card tier={1} pad={2}>
        {LIFTS.map((l, i) => {
          const few = fewpoints && i === 0;
          return (
            <div key={l.name}>
              <div onClick={() => onNav('lift', l)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '15px 14px', cursor: 'pointer' }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)', letterSpacing: '-0.01em' }}>{l.name}</div>
                  {few ? (
                    <div className="gb-mono" style={{ fontSize: 10.5, color: 'var(--ink3)', marginTop: 4, textTransform: 'uppercase', letterSpacing: '0.04em' }}>Log 2 more to see trend</div>
                  ) : (
                    <div style={{ marginTop: 5, display: 'flex', alignItems: 'baseline', gap: 6, whiteSpace: 'nowrap' }}>
                      <span className="gb-num" style={{ fontWeight: 800, fontSize: 21, color: 'var(--ink)', letterSpacing: '-0.035em' }}>{l.e1rm}<span style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink3)' }}> kg</span></span>
                      <span className="gb-label" style={{ fontSize: 9, color: 'var(--ink4)' }}>est. 1RM</span>
                    </div>
                  )}
                </div>
                <Sparkline data={few ? l.data.slice(0, 3) : l.data} dir={l.dir} dotsOnly={few} width={92} height={36} />
                {!few && <div style={{ width: 78, display: 'flex', justifyContent: 'flex-end' }}><DirTag dir={l.dir} label={l.delta} /></div>}
              </div>
              {i < LIFTS.length - 1 && <div className="rule" style={{ margin: '0 14px' }} />}
            </div>
          );
        })}
        {!fewpoints && (
          <>
            <div className="rule" style={{ margin: '0 14px' }} />
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '13px 14px' }}>
              <span style={{ width: 7, height: 7, borderRadius: 2, background: 'var(--warn)', flexShrink: 0 }} />
              <span style={{ fontSize: 12.5, color: 'var(--ink2)', lineHeight: 1.35 }}>Squat hasn’t moved in 4 sessions — <span style={{ color: 'var(--warn)', fontWeight: 700 }}>time to change something</span>.</span>
            </div>
          </>
        )}
      </Card>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Section 3 — Consistency
// ─────────────────────────────────────────────────────────────
function ConsistencySection({ onNav = () => {} }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      <SectionTitle right={<LinkMore label="Details" onClick={() => onNav('consistency')} />}>Consistency</SectionTitle>
      <Card tier={1} pad={18} onClick={() => onNav('consistency')} style={{ cursor: 'pointer' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 18 }}>
          <div>
            <div className="gb-num" style={{ fontSize: 40, fontWeight: 800, color: 'var(--ink)', lineHeight: 0.86, letterSpacing: '-0.045em' }}>78<span style={{ fontSize: 20, color: 'var(--ink3)' }}>%</span></div>
            <div className="gb-label" style={{ marginTop: 8, letterSpacing: '0.06em' }}>Hit goal · 9 of last 12 wks</div>
          </div>
          <span className="gb-mono" style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 11, fontWeight: 600, color: 'var(--ink2)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            <Icon name="flame" size={13} color="var(--ink3)" /> 5 wk streak
          </span>
        </div>
        <Heatmap weeks={WEEKS} />
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 14 }}><HeatLegend /></div>
      </Card>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Section 4 — Personal records (teaser)
// ─────────────────────────────────────────────────────────────
function AchievementSection({ nopr, onNav = () => {} }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      <SectionTitle right={!nopr && <LinkMore label="All records" onClick={() => onNav('records')} />}>Personal records</SectionTitle>
      {nopr ? (
        <Card tier={3} pad={16} style={{ display: 'flex', alignItems: 'center', gap: 13 }}>
          <IconTile name="trophy" size={40} ink="var(--ink3)" />
          <div style={{ fontSize: 12.5, color: 'var(--ink3)', lineHeight: 1.45 }}>Your first PR shows up here after a couple of sessions.</div>
        </Card>
      ) : (
        <Card tier={1} pad={15} onClick={() => onNav('records')} style={{ display: 'flex', alignItems: 'center', gap: 14, cursor: 'pointer' }}>
          <IconTile name="trophy" size={46} ink="var(--brand)" iconSize={22} bg="var(--brand-soft)" border="color-mix(in srgb, var(--brand) 22%, transparent)" />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
              <span style={{ fontSize: 16, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.02em' }}>Deadlift</span>
              <span className="gb-label" style={{ fontSize: 9, color: 'var(--brand-ink)', letterSpacing: '0.1em' }}>New best</span>
            </div>
            <div className="gb-mono" style={{ fontSize: 11.5, color: 'var(--ink3)', marginTop: 5, letterSpacing: '0' }}>140 kg × 3 · est. 1RM 153 · 2d ago</div>
          </div>
        </Card>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Section 5 — Body progress (invite only)
// ─────────────────────────────────────────────────────────────
function BodySection({ onNav = () => {} }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      <SectionTitle right={<span className="gb-label" style={{ fontSize: 9, color: 'var(--ink4)' }}>Soon</span>}>Body progress</SectionTitle>
      <Card tier={3} pad={16} onClick={() => onNav('body')} style={{ display: 'flex', alignItems: 'center', gap: 14, cursor: 'pointer' }}>
        <IconTile name="scale" size={42} ink="var(--ink2)" />
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--ink)', letterSpacing: '-0.01em' }}>Track your bodyweight</div>
          <div style={{ fontSize: 12, color: 'var(--ink3)', marginTop: 3, lineHeight: 1.45 }}>Log your weight in the daily check-in to see a smoothed trend here.</div>
        </div>
        <Icon name="chevR" size={17} color="var(--ink4)" strokeWidth={2} />
      </Card>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Section 6 — Coach acknowledgement (opt-in)
// ─────────────────────────────────────────────────────────────
function CoachToggle() {
  const [on, setOn] = useState(false);
  return (
    <button onClick={(e) => { e.stopPropagation(); setOn(o => !o); }} style={{
      width: 44, height: 26, borderRadius: 999, background: on ? 'var(--brand)' : 'var(--field)', padding: 3, flexShrink: 0,
      display: 'flex', justifyContent: on ? 'flex-end' : 'flex-start', border: 'none', cursor: 'pointer', boxShadow: 'var(--inset)', transition: 'background .2s, justify-content .2s',
    }}>
      <span style={{ width: 20, height: 20, borderRadius: '50%', background: '#fff', boxShadow: '0 1px 2px rgba(0,0,0,0.25)' }} />
    </button>
  );
}
function CoachSection({ onNav = () => {} }) {
  return (
    <Card tier={3} pad={15} onClick={() => onNav('coach')} style={{ display: 'flex', alignItems: 'center', gap: 13, cursor: 'pointer' }}>
      <div style={{ width: 42, height: 42, borderRadius: 11, flexShrink: 0, background: 'var(--card2)', border: '1px solid var(--line)', color: 'var(--ink)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: 16 }}>M</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--ink)', letterSpacing: '-0.01em' }}>Coach acknowledgements</div>
        <div style={{ fontSize: 12, color: 'var(--ink3)', marginTop: 2 }}>Let Coach Morgan cheer your sessions. Off by default.</div>
      </div>
      <CoachToggle />
    </Card>
  );
}

// ── Loading skeleton ──────────────────────────────────────────
function SkelLine({ w = '100%', h = 12, r = 6, style = {} }) {
  return <div className="gb-skel" style={{ width: w, height: h, borderRadius: r, ...style }} />;
}
function LoadingBody() {
  return (
    <>
      <div style={{ flexShrink: 0, background: 'var(--hero-bg)', borderRadius: 18, padding: '20px', boxShadow: 'var(--hero-shadow)' }}>
        <div className="gb-skel" style={{ width: '34%', height: 10, borderRadius: 5, background: 'rgba(255,255,255,0.12)' }} />
        <div className="gb-skel" style={{ width: '82%', height: 16, borderRadius: 6, marginTop: 12, background: 'rgba(255,255,255,0.12)' }} />
        <div style={{ height: 1, background: 'var(--hero-line)', margin: '18px 0' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
          <div className="gb-skel" style={{ width: 84, height: 84, borderRadius: '50%', background: 'rgba(255,255,255,0.10)' }} />
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 9 }}>
            <div className="gb-skel" style={{ width: '60%', height: 13, borderRadius: 6, background: 'rgba(255,255,255,0.12)' }} />
            <div className="gb-skel" style={{ width: '40%', height: 10, borderRadius: 5, background: 'rgba(255,255,255,0.10)' }} />
          </div>
        </div>
      </div>
      <Card tier={1} pad={2} style={{ flexShrink: 0 }}>
        {[0,1,2].map(i => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px', borderBottom: i < 2 ? '1px solid var(--line2)' : 'none' }}>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 7 }}><SkelLine w="42%" h={13} /><SkelLine w="30%" h={10} /></div>
            <SkelLine w={88} h={26} r={6} /><SkelLine w={56} h={14} r={5} />
          </div>
        ))}
      </Card>
      <Card tier={1} pad={17} style={{ flexShrink: 0 }}>
        <SkelLine w="42%" h={28} r={7} />
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(12,1fr)', gap: 4.5, marginTop: 18 }}>
          {Array.from({ length: 84 }).map((_, i) => <div key={i} className="gb-skel" style={{ aspectRatio: '1/1', borderRadius: 3 }} />)}
        </div>
      </Card>
    </>
  );
}

// ── New user first run ────────────────────────────────────────
function NewUserBody() {
  const previews = [
    { icon: 'chart', t: 'Strength trend', s: 'Each lift, week over week' },
    { icon: 'calendar', t: 'Consistency', s: 'A heatmap of every session' },
    { icon: 'trophy', t: 'Personal records', s: 'Every new best, by the lift' },
  ];
  return (
    <>
      <div style={{ flexShrink: 0, background: 'var(--hero-bg)', borderRadius: 18, padding: '24px 22px', color: 'var(--hero-fg)', boxShadow: 'var(--hero-shadow)' }}>
        <div className="gb-label" style={{ color: 'var(--hero-mut)' }}>Welcome to GymBro</div>
        <div style={{ fontSize: 25, fontWeight: 700, marginTop: 11, letterSpacing: '-0.025em', lineHeight: 1.18, textWrap: 'balance' }}>Start your first session to begin tracking.</div>
        <div style={{ fontSize: 13, color: 'var(--hero-mut)', marginTop: 10, lineHeight: 1.5 }}>Your progress is built from your own sessions — no fake numbers to start.</div>
        <button style={{ width: '100%', height: 50, borderRadius: 12, border: 'none', cursor: 'pointer', marginTop: 20, background: '#fff', color: '#15171c', font: '700 15px var(--sans)', letterSpacing: '-0.01em', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, whiteSpace: 'nowrap' }}>
          <Icon name="plus" size={18} color="#15171c" strokeWidth={2.4} /> Start a workout
        </button>
      </div>
      <div className="gb-label" style={{ marginLeft: 2, marginTop: 2, flexShrink: 0 }}>What you’ll see here</div>
      {previews.map(p => (
        <Card key={p.t} tier={3} pad={13} style={{ display: 'flex', alignItems: 'center', gap: 13 }}>
          <IconTile name={p.icon} size={40} ink="var(--ink2)" />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--ink)', letterSpacing: '-0.01em' }}>{p.t}</div>
            <div style={{ fontSize: 12, color: 'var(--ink3)', marginTop: 2 }}>{p.s}</div>
          </div>
        </Card>
      ))}
    </>
  );
}

// ── Error ─────────────────────────────────────────────────────
function ErrorBody() {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '0 36px', gap: 8 }}>
      <div style={{ width: 64, height: 64, borderRadius: 16, background: 'var(--card2)', border: '1px solid var(--line)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 10 }}>
        <Icon name="cloudOff" size={30} color="var(--ink3)" />
      </div>
      <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.02em', lineHeight: 1.2, maxWidth: 260 }}>Couldn’t load your progress</div>
      <div style={{ fontSize: 13, color: 'var(--ink3)', lineHeight: 1.5, maxWidth: 250 }}>Check your connection and try again — your data is safe.</div>
      <button style={{ height: 46, padding: '0 26px', borderRadius: 12, border: 'none', cursor: 'pointer', marginTop: 16, background: 'var(--brand-grad)', color: 'var(--btn-fg)', font: '700 14px var(--sans)', letterSpacing: '-0.01em', display: 'inline-flex', alignItems: 'center', gap: 8 }}>
        <Icon name="refresh" size={17} color="var(--btn-fg)" /> Retry
      </button>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
function ProgressBody({ state, onNav = () => {} }) {
  if (state === 'loading') return <LoadingBody />;
  if (state === 'newuser') return <NewUserBody />;
  const noplan = state === 'noplan', fewpoints = state === 'fewpoints', nopr = state === 'nopr';
  const blocks = [
    <StatusSection noplan={noplan} onNav={onNav} />,
    <StrengthSection fewpoints={fewpoints} onNav={onNav} />,
    <ConsistencySection onNav={onNav} />,
    <AchievementSection nopr={nopr} onNav={onNav} />,
    <BodySection onNav={onNav} />,
    <CoachSection onNav={onNav} />,
  ];
  return (
    <>
      {state === 'refresh' && (
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, marginTop: -2, marginBottom: 4 }}>
          <Icon name="refresh" size={15} color="var(--ink3)" style={{ animation: 'gbSpin 0.9s linear infinite' }} />
          <span className="gb-label" style={{ color: 'var(--ink3)' }}>Refreshing</span>
        </div>
      )}
      {blocks.map((b, i) => <div key={i} style={{ flexShrink: 0 }}>{b}</div>)}
    </>
  );
}

function ProgressScreen({ state = 'home', dark = false, onNav = () => {} }) {
  const sub = state === 'noplan' ? 'Ad-hoc training' : state === 'newuser' ? 'Let’s get started' : 'Hypertrophy Block A';
  return (
    <div className={dark ? 'gb-dark' : ''} style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--paper)', color: 'var(--ink)', fontFamily: 'var(--sans)' }}>
      <Header sub={sub} onNav={onNav} />
      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: state === 'error' ? 0 : 24, padding: state === 'error' ? 0 : '20px 16px 30px' }}>
        {state === 'error' ? <ErrorBody /> : <ProgressBody state={state} onNav={onNav} />}
      </div>
      <BottomNav active="progress" onNav={onNav} />
    </div>
  );
}

Object.assign(window, { ProgressScreen });

// ── Anatomy / annotations panel ───────────────────────────────
const DECISIONS = [
  { n: 1, t: 'This-week status', d: 'Do I need to train again this week, or am I fine?', p: 'P0' },
  { n: 2, t: 'Strength progress', d: 'Push, hold, or change this lift.', p: 'P0' },
  { n: 3, t: 'Consistency', d: 'Re-engage after a gap, or protect a building routine.', p: 'P1' },
  { n: 4, t: 'Personal records', d: 'Reinforce what worked; which lift to keep pushing.', p: 'P1' },
  { n: 5, t: 'Body progress', d: 'Stay the course or adjust — without panicking at a spike.', p: 'P2' },
  { n: 6, t: 'Coach feedback', d: 'Relatedness — a teammate noticed. Opt-in, never ranked.', p: '—' },
];
function AnnotationsPanel() {
  return (
    <div style={{ height: '100%', background: 'var(--paper)', fontFamily: 'var(--sans)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '28px 26px 22px', borderBottom: '1px solid var(--line)' }}>
        <div className="gb-label">The 5-second rule</div>
        <div style={{ fontSize: 24, fontWeight: 800, color: 'var(--ink)', letterSpacing: '-0.03em', marginTop: 9, textWrap: 'balance', lineHeight: 1.12 }}>One thought, settled before you read.</div>
        <div style={{ fontSize: 13, color: 'var(--ink2)', marginTop: 10, lineHeight: 1.55 }}>
          “Am I getting stronger, and on track this week?” The verdict comes first; every card below earns its place by driving exactly one decision.
        </div>
        <div style={{ display: 'flex', gap: 6, marginTop: 15, flexWrap: 'wrap' }}>
          {['Verdict first', 'Self-referenced', 'Forgiving', 'Never fabricated'].map(t => (
            <span key={t} className="gb-mono" style={{ fontSize: 10, fontWeight: 600, color: 'var(--ink2)', border: '1px solid var(--line)', borderRadius: 6, padding: '4px 9px', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{t}</span>
          ))}
        </div>
      </div>
      <div style={{ flex: 1, padding: '4px 0' }}>
        {DECISIONS.map((it, i) => (
          <div key={it.n} style={{ display: 'flex', gap: 14, padding: '15px 26px', borderBottom: i < DECISIONS.length - 1 ? '1px solid var(--line2)' : 'none' }}>
            <div className="gb-num" style={{ width: 26, height: 26, borderRadius: 8, flexShrink: 0, background: 'var(--ink)', color: 'var(--paper)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12.5, fontWeight: 800 }}>{it.n}</div>
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: 14.5, fontWeight: 700, color: 'var(--ink)', letterSpacing: '-0.01em' }}>{it.t}</span>
                <span className="gb-label" style={{ fontSize: 9, color: 'var(--ink4)', border: '1px solid var(--line)', borderRadius: 5, padding: '1px 5px' }}>{it.p}</span>
              </div>
              <div style={{ fontSize: 12.5, color: 'var(--ink2)', marginTop: 4, lineHeight: 1.45 }}>
                <span className="gb-mono" style={{ fontWeight: 600, color: 'var(--ink3)', fontSize: 10.5, textTransform: 'uppercase', letterSpacing: '0.04em' }}>Decision — </span>{it.d}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { ProgressScreen, AnnotationsPanel });
