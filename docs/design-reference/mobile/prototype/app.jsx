// GymBro Mobile prototype — root. Holds high-level navigation state and renders
// the SAME GymBro screen inside an iOS frame and an Android frame, side by side.
// Two roles: Trainee (Client) and Coach (Owner), covering the full flow
// ① sign up → ② connect → ③ build → ④ assign → ⑤ start → ⑥ log → ⑦ progress.

const { useState, useEffect } = React;

const TRAINEE_TABS = [
  { id: 'log', label: 'Log', icon: 'history' },
  { id: 'plan', label: 'Plan', icon: 'calendar' },
  { id: 'progress', label: 'Progress', icon: 'bars' },
  { id: 'profile', label: 'Profile', icon: 'user' },
];
const COACH_TABS = [
  { id: 'clients', label: 'Clients', icon: 'users' },
  { id: 'plans', label: 'Plans', icon: 'clipboard' },
  { id: 'profile', label: 'Profile', icon: 'user' },
];

const TRAINEE_FLOWS = [
  { id: 'auth', label: 'Auth' },
  { id: 'log', label: 'Workout Log' },
  { id: 'live', label: 'Live Session' },
  { id: 'detail', label: 'Session Detail' },
];
const COACH_FLOWS = [
  { id: 'auth', label: 'Auth' },
  { id: 'clients', label: 'Clients' },
  { id: 'builder', label: 'Plan Builder' },
  { id: 'assign', label: 'Assign' },
  { id: 'client', label: 'Monitor' },
];

const CAPTIONS = {
  auth: 'Sign up (your workspace is created as Owner), log in, or join a coach with an 8-char invite code. One adaptive layout; platform-native chrome.',
  log: 'The session-first Workout Log — active-session hero, weekly goal ring, filter chips and Monday-anchored week groups. Volume in kg, the stored unit.',
  live: 'Full-screen focus mode: log each set (warm-up/working/drop/AMRAP) with steppers, e1RM, auto rest timer, substitute or skip, finish or abandon. One active session at a time.',
  detail: 'Post-session summary: duration, volume, sets, RPE, PRs and per-working-set estimated 1RM, with a full set breakdown. Repeat in one tap.',
  clients: 'Coach home — your roster with per-client adherence rings, plan + visibility mode, and an invite generator (8-char, single-use, 7-day codes).',
  builder: 'Plan builder — workouts → exercises → prescribed sets. Saving forks an immutable new version; older versions stay frozen as history.',
  assign: 'Assign a plan — pick a client, set frequency (1–7/wk) and a visibility mode (Full / Guided / Blind) with hide flags. The assignment pins the current version.',
  client: 'Client monitor — adherence, volume and PRs, the version-pinned assignment with apply-latest and pause/resume, and recent sessions (WorkoutLogViewAll).',
};

function load(key, def) { try { const v = localStorage.getItem('gbm_' + key); return v == null ? def : JSON.parse(v); } catch { return def; } }
function save(key, val) { try { localStorage.setItem('gbm_' + key, JSON.stringify(val)); } catch {} }

function MobileApp() {
  const [phase, setPhase] = useState(() => load('phase', 'auth'));   // auth | app
  const [role, setRole] = useState(() => load('role', 'trainee'));   // trainee | coach
  const [route, setRoute] = useState(() => load('route', 'shell'));  // shell | live | detail | builder | assign | client
  const [tab, setTab] = useState(() => load('tab', 'log'));
  const [fromFinish, setFromFinish] = useState(false);
  const [selClient, setSelClient] = useState(null);
  const [selPlan, setSelPlan] = useState(null);
  const [builderNew, setBuilderNew] = useState(false);
  const [assignFrom, setAssignFrom] = useState('plans');

  useEffect(() => save('phase', phase), [phase]);
  useEffect(() => save('role', role), [role]);
  useEffect(() => save('route', route), [route]);
  useEffect(() => save('tab', tab), [tab]);

  function setRoleHome(r) {
    setRole(r); setRoute('shell'); setTab(r === 'coach' ? 'clients' : 'log');
  }

  const h = {
    // shared
    onAuthed: () => { setPhase('app'); setRoleHome(role); },
    onSignOut: () => { setPhase('auth'); setRoute('shell'); },
    setTab,
    // trainee
    onResume: () => setRoute('live'),
    onStart: () => setRoute('live'),
    onOpenSession: () => { setFromFinish(false); setRoute('detail'); },
    onComplete: () => { setFromFinish(true); setRoute('detail'); },
    onAbandon: () => { setRoute('shell'); setTab('log'); },
    onBackDetail: () => { if (role === 'coach') { setRoute('client'); } else { setRoute('shell'); setTab('log'); } },
    // coach
    onOpenClient: (c) => { setSelClient(c); setRoute('client'); },
    onOpenPlan: (p) => { setSelPlan(p); setBuilderNew(false); setRoute('builder'); },
    onNewPlan: () => { setBuilderNew(true); setRoute('builder'); },
    onAssign: (p) => { if (p) setSelPlan(p); setAssignFrom(route === 'client' ? 'client' : 'plans'); setRoute('assign'); },
    onBackBuilder: () => { setRoute('shell'); setTab('plans'); },
    onBackAssign: () => { if (assignFrom === 'client') { setRoute('client'); } else { setRoute('shell'); setTab('plans'); } },
    onBackClient: () => { setRoute('shell'); setTab('clients'); },
    onCoachOpenSession: () => { setFromFinish(false); setRoute('detail'); },
  };

  // Flow switcher
  const flowsForRole = role === 'coach' ? COACH_FLOWS : TRAINEE_FLOWS;
  const flow = phase === 'auth' ? 'auth'
    : role === 'coach'
      ? (route === 'builder' ? 'builder' : route === 'assign' ? 'assign' : route === 'client' ? 'client' : 'clients')
      : (route === 'live' ? 'live' : route === 'detail' ? 'detail' : 'log');

  function jump(id) {
    if (id === 'auth') { setPhase('auth'); setRoute('shell'); return; }
    setPhase('app');
    if (role === 'coach') {
      if (id === 'clients') { setRoute('shell'); setTab('clients'); }
      else if (id === 'builder') { setBuilderNew(false); setSelPlan(COACH_PLANS[0]); setRoute('builder'); }
      else if (id === 'assign') { setSelPlan(COACH_PLANS[0]); setAssignFrom('plans'); setRoute('assign'); }
      else if (id === 'client') { setSelClient(CLIENTS[0]); setRoute('client'); }
    } else {
      if (id === 'log') { setRoute('shell'); setTab('log'); }
      else if (id === 'live') setRoute('live');
      else if (id === 'detail') { setFromFinish(false); setRoute('detail'); }
    }
  }

  function switchRole(r) {
    if (r === role) return;
    setRole(r);
    if (phase === 'app') setRoleHome(r);
  }

  // fit two phones to viewport
  const [scale, setScale] = useState(1);
  useEffect(() => {
    function fit() {
      const avail = window.innerWidth - 48;
      const natural = 402 + 412 + 72;
      setScale(Math.min(1, avail / natural));
    }
    fit();
    window.addEventListener('resize', fit);
    return () => window.removeEventListener('resize', fit);
  }, []);

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      {/* Top toolbar */}
      <header style={{
        position: 'sticky', top: 0, zIndex: 50, display: 'flex', alignItems: 'center', gap: 14,
        padding: '12px 22px', background: 'rgba(13,20,38,0.86)', backdropFilter: 'blur(14px)',
        borderBottom: '1px solid rgba(255,255,255,0.08)', flexWrap: 'wrap',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
          <BrandMark size={34} radius={10} />
          <div>
            <div style={{ color: '#fff', fontWeight: 800, fontSize: 15, letterSpacing: '-0.01em' }}>GymBro Mobile</div>
            <div style={{ color: 'rgba(255,255,255,0.5)', fontSize: 11.5 }}>Flutter prototype · iOS + Android</div>
          </div>
        </div>

        {/* Role toggle */}
        <div style={{ display: 'flex', gap: 4, background: 'rgba(255,255,255,0.07)', padding: 4, borderRadius: 11 }}>
          {[['trainee', 'Trainee'], ['coach', 'Coach']].map(([id, label]) => {
            const on = role === id;
            return (
              <button key={id} onClick={() => switchRole(id)} style={{
                height: 32, padding: '0 14px', borderRadius: 8, border: 'none', cursor: 'pointer', font: '700 13px var(--inv-font-sans)',
                background: on ? 'var(--inv-primary-500)' : 'transparent', color: on ? '#fff' : 'rgba(255,255,255,0.7)',
              }}>{label}</button>
            );
          })}
        </div>

        <div style={{ display: 'flex', gap: 6, background: 'rgba(255,255,255,0.07)', padding: 4, borderRadius: 11, flexWrap: 'wrap' }}>
          {flowsForRole.map(f => {
            const on = flow === f.id;
            return (
              <button key={f.id} onClick={() => jump(f.id)} style={{
                height: 32, padding: '0 13px', borderRadius: 8, border: 'none', cursor: 'pointer', font: '600 13px var(--inv-font-sans)',
                background: on ? '#fff' : 'transparent', color: on ? 'var(--inv-primary-700)' : 'rgba(255,255,255,0.7)',
              }}>{f.label}</button>
            );
          })}
        </div>

        <div style={{ flex: 1 }} />
        <a href="GymBro%20Mobile%20Strategy.html" style={{
          display: 'inline-flex', alignItems: 'center', gap: 7, height: 36, padding: '0 15px', borderRadius: 10,
          background: 'rgba(255,255,255,0.1)', color: '#fff', textDecoration: 'none', fontWeight: 600, fontSize: 13,
          border: '1px solid rgba(255,255,255,0.14)',
        }}>
          <Icon name="layers" size={16} /> Strategy &amp; architecture
        </a>
      </header>

      {/* Stage */}
      <div style={{ flex: 1, padding: '30px 24px 10px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div style={{ height: 932 * scale + 44, width: '100%', display: 'flex', justifyContent: 'center' }}>
          <div style={{ transform: `scale(${scale})`, transformOrigin: 'top center', display: 'flex', gap: 72, alignItems: 'flex-start' }}>
            <PhoneFigure label="iOS" sub="iPhone · Cupertino">
              <IOSDevice>
                <AppContent platform="ios" phase={phase} role={role} route={route} tab={tab} fromFinish={fromFinish} selClient={selClient} selPlan={selPlan} builderNew={builderNew} h={h} />
              </IOSDevice>
            </PhoneFigure>
            <PhoneFigure label="Android" sub="Material 3">
              <AndroidDevice>
                <AppContent platform="android" phase={phase} role={role} route={route} tab={tab} fromFinish={fromFinish} selClient={selClient} selPlan={selPlan} builderNew={builderNew} h={h} />
              </AndroidDevice>
            </PhoneFigure>
          </div>
        </div>

        {/* Caption */}
        <div style={{ maxWidth: 700, textAlign: 'center', marginTop: 6, padding: '0 16px 24px' }}>
          <div style={{ color: '#fff', fontWeight: 800, fontSize: 16, marginBottom: 6 }}>
            {(role === 'coach' ? COACH_FLOWS : TRAINEE_FLOWS).find(f => f.id === flow)?.label}
            <span style={{ color: 'rgba(255,255,255,0.4)', fontWeight: 600, fontSize: 13 }}>  ·  {role === 'coach' ? 'Coach (Owner)' : 'Trainee (Client)'}</span>
          </div>
          <p style={{ color: 'rgba(255,255,255,0.6)', fontSize: 13.5, lineHeight: 1.6, margin: 0 }}>{CAPTIONS[flow]}</p>
        </div>
      </div>
    </div>
  );
}

function PhoneFigure({ label, sub, children }) {
  return (
    <figure style={{ margin: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
      <figcaption style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{ color: '#fff', fontWeight: 700, fontSize: 14 }}>{label}</span>
        <span style={{ color: 'rgba(255,255,255,0.4)', fontSize: 12 }}>{sub}</span>
      </figcaption>
      {children}
    </figure>
  );
}

function AppContent({ platform, phase, role, route, tab, fromFinish, selClient, selPlan, builderNew, h }) {
  if (phase === 'auth') {
    return <AuthScreen platform={platform} onAuthed={h.onAuthed} />;
  }

  // Full-screen routes (no tab bar)
  if (route === 'live') return <ActiveSessionScreen platform={platform} onComplete={h.onComplete} onAbandon={h.onAbandon} />;
  if (route === 'detail') return <SessionDetailScreen platform={platform} onBack={h.onBackDetail} fromFinish={fromFinish} />;
  if (route === 'builder') return <PlanBuilderScreen platform={platform} plan={selPlan} isNew={builderNew} onBack={h.onBackBuilder} />;
  if (route === 'assign') return <AssignScreen platform={platform} plan={selPlan} onBack={h.onBackAssign} />;
  if (route === 'client') return <ClientMonitorScreen platform={platform} client={selClient} onBack={h.onBackClient} onAssign={h.onAssign} onOpenSession={h.onCoachOpenSession} />;

  // Shell with tab bar
  let screen, tabs;
  if (role === 'coach') {
    tabs = COACH_TABS;
    if (tab === 'clients') screen = <ClientsScreen platform={platform} onOpenClient={h.onOpenClient} />;
    else if (tab === 'plans') screen = <PlansScreen platform={platform} onOpenPlan={h.onOpenPlan} onAssign={h.onAssign} onNew={h.onNewPlan} />;
    else screen = <ProfileScreen platform={platform} coach onSignOut={h.onSignOut} />;
  } else {
    tabs = TRAINEE_TABS;
    if (tab === 'log') screen = <WorkoutLogScreen platform={platform} onResume={h.onResume} onOpenSession={h.onOpenSession} onStart={h.onStart} />;
    else if (tab === 'plan') screen = <PlanScreen platform={platform} />;
    else if (tab === 'progress') screen = <ProgressScreen platform={platform} />;
    else screen = <ProfileScreen platform={platform} onSignOut={h.onSignOut} />;
  }

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ flex: 1, minHeight: 0 }}>{screen}</div>
      <TabBar tabs={tabs} active={tab} onChange={h.setTab} platform={platform} />
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<MobileApp />);
