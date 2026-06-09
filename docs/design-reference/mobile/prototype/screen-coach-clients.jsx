// GymBro Mobile — Coach: Clients tab, Invite sheet, Client monitor.
// Mirrors the membership + monitoring rules: 8-char single-use invites,
// per-client visibility, WorkoutLogViewAll, version-pinned assignments.

function VisBadge({ mode }) {
  if (!mode || mode === '—') return null;
  const map = {
    Full: ['var(--inv-success-0)', 'var(--inv-success-300)', 'eye'],
    Guided: ['var(--inv-secondary-0)', 'var(--inv-secondary-300)', 'sliders'],
    Blind: ['var(--inv-grey-25)', 'var(--inv-grey-600)', 'lock'],
  };
  const [bg, fg, ic] = map[mode] || map.Full;
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, borderRadius: 6, padding: '2px 7px', fontSize: 11, fontWeight: 700, background: bg, color: fg }}>
      <Icon name={ic} size={11} /> {mode}
    </span>
  );
}

const FLAG_STYLE = {
  'on-track': ['var(--inv-success-0)', 'var(--inv-success-300)', 'On track'],
  'behind': ['var(--inv-warning-0)', 'var(--inv-warning-300)', 'Behind'],
  'unassigned': ['var(--inv-grey-25)', 'var(--inv-grey-600)', 'No plan'],
};

function ClientRow({ c, onClick }) {
  const [bg, fg, label] = FLAG_STYLE[c.flag] || FLAG_STYLE['on-track'];
  return (
    <button onClick={onClick} style={{
      width: '100%', textAlign: 'left', cursor: 'pointer', background: 'var(--inv-surface-base)',
      border: '1px solid var(--inv-border-card)', borderRadius: 14, padding: 12,
      display: 'flex', gap: 12, alignItems: 'center', marginBottom: 8, boxShadow: 'var(--inv-shadow-card)',
    }}>
      <div style={{ width: 44, height: 44, borderRadius: '50%', background: 'var(--inv-primary-500)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 17, flexShrink: 0 }}>{c.initial}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, flexWrap: 'wrap' }}>
          <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--inv-grey-900)' }}>{c.name}</span>
          <VisBadge mode={c.visibility} />
        </div>
        <div style={{ fontSize: 12.5, color: 'var(--inv-grey-500)', marginTop: 2 }}>{c.plan}</div>
        <div style={{ display: 'flex', gap: 10, marginTop: 5, alignItems: 'center' }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 11.5, fontWeight: 700, borderRadius: 999, padding: '2px 8px', background: bg, color: fg }}>{label}</span>
          <span style={{ fontSize: 11.5, color: 'var(--inv-grey-400)' }}>Last: {c.last}</span>
        </div>
      </div>
      {c.goal > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
          <Ring value={c.done} total={c.goal} size={34} stroke={4} />
          <span style={{ fontSize: 10, fontWeight: 700, color: 'var(--inv-grey-500)' }}>{c.done}/{c.goal}</span>
        </div>
      )}
    </button>
  );
}

function ClientsScreen({ platform, onOpenClient }) {
  const [sheet, setSheet] = React.useState(false);
  const [invites, setInvites] = React.useState(INVITES);
  const [fresh, setFresh] = React.useState(null);

  function generate() {
    const alpha = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    for (let i = 0; i < 8; i++) code += alpha[Math.floor(Math.random() * alpha.length)];
    setFresh(code);
    setInvites(prev => [{ code, created: 'just now', expires: 'in 7 days', email: null }, ...prev]);
  }
  function revoke(code) { setInvites(prev => prev.filter(i => i.code !== code)); if (fresh === code) setFresh(null); }

  const active = CLIENTS.filter(c => c.status === 'active').length;
  const logged = CLIENTS.reduce((n, c) => n + c.done, 0);

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--inv-grey-0)' }}>
      <div style={{ flexShrink: 0, paddingTop: safeTop(platform), background: 'var(--inv-surface-base)', borderBottom: '1px solid var(--inv-border-card)' }}>
        <div style={{ padding: '8px 18px 12px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <BrandMark size={36} radius={10} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12, color: 'var(--inv-grey-500)' }}>{COACH.workspace}</div>
            <div style={{ fontSize: 19, fontWeight: 800, color: 'var(--inv-grey-900)', letterSpacing: '-0.01em' }}>Clients</div>
          </div>
          <button onClick={() => setSheet(true)} style={{ height: 38, padding: '0 14px', borderRadius: 10, border: 'none', cursor: 'pointer', background: 'var(--inv-primary-500)', color: '#fff', font: '700 13px var(--inv-font-sans)', display: 'inline-flex', alignItems: 'center', gap: 6, boxShadow: '0 2px 8px rgba(37,99,235,0.28)' }}>
            <Icon name="userPlus" size={17} /> Invite
          </button>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 18px 90px' }}>
        <div style={{ display: 'flex', gap: 10, marginBottom: 14 }}>
          <div style={{ flex: 1, background: 'var(--inv-surface-base)', border: '1px solid var(--inv-border-card)', borderRadius: 12, padding: '12px 14px', boxShadow: 'var(--inv-shadow-card)' }}>
            <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--inv-grey-900)' }}>{CLIENTS.length}</div>
            <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--inv-grey-400)' }}>CLIENTS</div>
          </div>
          <div style={{ flex: 1, background: 'var(--inv-surface-base)', border: '1px solid var(--inv-border-card)', borderRadius: 12, padding: '12px 14px', boxShadow: 'var(--inv-shadow-card)' }}>
            <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--inv-grey-900)' }}>{active}</div>
            <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--inv-grey-400)' }}>ACTIVE</div>
          </div>
          <div style={{ flex: 1, background: 'var(--inv-surface-base)', border: '1px solid var(--inv-border-card)', borderRadius: 12, padding: '12px 14px', boxShadow: 'var(--inv-shadow-card)' }}>
            <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--inv-primary-600)' }}>{logged}</div>
            <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--inv-grey-400)' }}>SESSIONS / WK</div>
          </div>
        </div>

        {CLIENTS.map(c => <ClientRow key={c.id} c={c} onClick={() => onOpenClient(c)} />)}
      </div>

      {/* Invite sheet */}
      <BottomSheet open={sheet} onClose={() => setSheet(false)} height="80%">
        <div style={{ padding: '6px 18px 0', display: 'flex', flexDirection: 'column', minHeight: 0, flex: 1 }}>
          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--inv-grey-900)' }}>Invite a client</div>
          <div style={{ fontSize: 13, color: 'var(--inv-grey-500)', marginTop: 2, marginBottom: 14 }}>Codes are single-use, expire in 7 days, and always join as a Client.</div>

          {fresh ? (
            <div style={{ borderRadius: 14, padding: 16, background: 'var(--inv-primary-0)', border: '1.5px solid var(--inv-primary-200)', marginBottom: 14, flexShrink: 0 }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--inv-primary-700)', letterSpacing: '0.08em' }}>NEW INVITE CODE</div>
              <div style={{ fontSize: 30, fontWeight: 800, letterSpacing: '0.14em', color: 'var(--inv-grey-900)', margin: '8px 0 12px', fontFamily: 'var(--inv-font-sans)' }}>{fresh}</div>
              <div style={{ display: 'flex', gap: 8 }}>
                <GbButton size="sm" icon="copy" label="Copy" severity="secondary" outlined style={{ flex: 1 }} />
                <GbButton size="sm" icon="share" label="Share" style={{ flex: 1 }} />
              </div>
            </div>
          ) : (
            <GbButton full icon="ticket" label="Generate invite code" onClick={generate} style={{ marginBottom: 14, flexShrink: 0 }} />
          )}

          <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--inv-grey-900)', marginBottom: 8, flexShrink: 0 }}>Active invites · {invites.length}</div>
          <div style={{ flex: 1, overflowY: 'auto', paddingBottom: bottomInset(platform) + 12 }}>
            {invites.map(inv => (
              <div key={inv.code} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12, background: 'var(--inv-surface-base)', border: '1px solid var(--inv-border-card)', borderRadius: 12, marginBottom: 8 }}>
                <div style={{ width: 38, height: 38, borderRadius: 10, background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name="ticket" size={19} color="var(--inv-grey-500)" />
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 15, fontWeight: 800, letterSpacing: '0.08em', color: 'var(--inv-grey-900)' }}>{inv.code}</div>
                  <div style={{ fontSize: 11.5, color: 'var(--inv-grey-500)' }}>{inv.email ? inv.email + ' · ' : ''}Expires {inv.expires}</div>
                </div>
                <button onClick={() => revoke(inv.code)} style={{ width: 34, height: 34, borderRadius: 9, border: '1px solid var(--inv-border-card)', background: 'var(--inv-surface-base)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name="trash" size={17} color="var(--inv-error-100)" />
                </button>
              </div>
            ))}
          </div>
        </div>
      </BottomSheet>
    </div>
  );
}

function ClientMonitorScreen({ platform, client, onBack, onAssign, onOpenSession }) {
  const c = client || CLIENTS[0];
  const [paused, setPaused] = React.useState(false);
  const [applied, setApplied] = React.useState(false);
  const recent = [
    { id: 'r1', name: 'Push Day', day: 'WED', source: 'plan', status: 'done', rel: 'Today', dur: 2520, vol: 4200, rpe: 7, pr: 1 },
    { id: 'r2', name: 'Pull Day', day: 'MON', source: 'plan', status: 'done', rel: 'Mon', dur: 2640, vol: 4350, rpe: 7, pr: 0 },
    { id: 'r3', name: 'Mobility', day: 'SUN', source: 'adhoc', status: 'done', rel: 'Sun', dur: 1080, vol: 0, rpe: 4, pr: 0 },
  ];
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--inv-grey-0)' }}>
      <div style={{ flexShrink: 0, paddingTop: safeTop(platform), background: 'var(--inv-surface-base)', borderBottom: '1px solid var(--inv-border-card)' }}>
        <div style={{ padding: '8px 12px 12px', display: 'flex', alignItems: 'center', gap: 8 }}>
          <button onClick={onBack} style={{ width: 40, height: 40, borderRadius: '50%', border: 'none', background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name="chevL" size={20} color="var(--inv-grey-700)" />
          </button>
          <div style={{ flex: 1, fontSize: 16, fontWeight: 800, color: 'var(--inv-grey-900)' }}>Client</div>
          <button style={{ width: 40, height: 40, borderRadius: '50%', border: 'none', background: 'var(--inv-grey-0)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name="more" size={20} color="var(--inv-grey-700)" />
          </button>
        </div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 18px 18px' }}>
        {/* Identity */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 16 }}>
          <div style={{ width: 56, height: 56, borderRadius: '50%', background: 'var(--inv-primary-500)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: 22 }}>{c.initial}</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 19, fontWeight: 800, color: 'var(--inv-grey-900)' }}>{c.name}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 3 }}>
              <span style={{ fontSize: 12, color: 'var(--inv-grey-500)' }}>Client · {c.streak}-day streak</span>
            </div>
          </div>
          <Ring value={c.done} total={c.goal || 1} size={48} stroke={5}>
            <span style={{ fontSize: 12, fontWeight: 800, color: 'var(--inv-grey-900)' }}>{c.done}/{c.goal || 0}</span>
          </Ring>
        </div>

        {/* Stats */}
        <div style={{ display: 'flex', gap: 10, marginBottom: 16 }}>
          <StatTile icon="history" value={c.done} label="THIS WK" />
          <StatTile icon="bars" value={fmtVolume(c.volumeKg)} unit="kg" label="VOLUME" accent="var(--inv-primary-500)" />
          <StatTile icon="trophy" value="1" label="PRS" accent="var(--inv-warning-200)" />
        </div>

        {/* Assignment */}
        {c.flag !== 'unassigned' ? (
          <div style={{ background: 'var(--inv-surface-base)', border: '1px solid var(--inv-border-card)', borderRadius: 14, padding: 16, boxShadow: 'var(--inv-shadow-card)', marginBottom: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
              <span style={{ fontSize: 14, fontWeight: 800, color: 'var(--inv-grey-900)', flex: 1 }}>Current assignment</span>
              {paused && <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--inv-warning-300)', background: 'var(--inv-warning-0)', borderRadius: 6, padding: '2px 8px' }}>Paused</span>}
              <VisBadge mode={c.visibility} />
            </div>
            <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--inv-grey-900)' }}>{c.plan}</div>
            <div style={{ display: 'flex', gap: 14, margintop: 4, marginTop: 4, fontSize: 12, color: 'var(--inv-grey-500)' }}>
              <span>Pinned v2</span><span>·</span><span>{c.goal}×/week</span><span>·</span><span>Started May 18</span>
            </div>
            {!applied && (
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 12, padding: '10px 12px', borderRadius: 10, background: 'var(--inv-secondary-0)', border: '1px solid var(--inv-primary-25)' }}>
                <Icon name="refresh" size={16} color="var(--inv-primary-600)" />
                <span style={{ flex: 1, fontSize: 12, color: 'var(--inv-grey-700)' }}>Newer version <b>v3</b> available</span>
                <button onClick={() => setApplied(true)} style={{ height: 30, padding: '0 12px', borderRadius: 8, border: 'none', cursor: 'pointer', background: 'var(--inv-primary-500)', color: '#fff', font: '700 12px var(--inv-font-sans)' }}>Apply latest</button>
              </div>
            )}
            {applied && (
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 12, padding: '10px 12px', borderRadius: 10, background: 'var(--inv-success-0)', border: '1px solid var(--inv-success-50)' }}>
                <Icon name="check" size={16} color="var(--inv-success-300)" />
                <span style={{ flex: 1, fontSize: 12, color: 'var(--inv-success-300)', fontWeight: 600 }}>Updated to v3 — snapshot preserved</span>
              </div>
            )}
            <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
              <GbButton size="sm" severity="secondary" outlined icon={paused ? 'play' : 'pause'} label={paused ? 'Resume' : 'Pause'} onClick={() => setPaused(!paused)} style={{ flex: 1 }} />
              <GbButton size="sm" severity="secondary" outlined icon="edit" label="Reassign" onClick={onAssign} style={{ flex: 1 }} />
            </div>
          </div>
        ) : (
          <div style={{ background: 'var(--inv-surface-base)', border: '1px dashed var(--inv-border-field)', borderRadius: 14, padding: 18, textAlign: 'center', marginBottom: 16 }}>
            <Icon name="calendar" size={26} color="var(--inv-grey-300)" style={{ margin: '0 auto 8px' }} />
            <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--inv-grey-700)' }}>No active plan</div>
            <div style={{ fontSize: 12, color: 'var(--inv-grey-400)', marginBottom: 12 }}>Assign a plan to start coaching {c.name.split(' ')[0]}.</div>
            <GbButton label="Assign a plan" icon="plus" onClick={onAssign} />
          </div>
        )}

        {/* Recent sessions */}
        <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--inv-grey-900)', marginBottom: 10 }}>Recent sessions</div>
        {c.flag === 'unassigned' ? (
          <div style={{ fontSize: 13, color: 'var(--inv-grey-400)', textAlign: 'center', padding: 20 }}>No sessions logged yet.</div>
        ) : recent.map(s => (
          <button key={s.id} onClick={onOpenSession} style={{ width: '100%', textAlign: 'left', cursor: 'pointer', background: 'var(--inv-surface-base)', border: '1px solid var(--inv-border-card)', borderRadius: 12, padding: 11, display: 'flex', gap: 12, alignItems: 'center', marginBottom: 8 }}>
            <DayBadge day={s.day} status={s.status} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                <span style={{ fontSize: 14, fontWeight: 700, color: 'var(--inv-grey-900)' }}>{s.name}</span>
                <SourceTag source={s.source} small />
              </div>
              <div style={{ display: 'flex', gap: 10, marginTop: 4, fontSize: 12, color: 'var(--inv-grey-500)' }}>
                <span>{s.rel}</span>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3 }}><Icon name="clock" size={12} />{fmtDuration(s.dur)}</span>
                {s.vol > 0 && <span>{fmtVolume(s.vol)}kg</span>}
              </div>
            </div>
            {s.pr > 0 && <PRChip small />}
            <Icon name="chevR" size={16} color="var(--inv-grey-300)" />
          </button>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { ClientsScreen, ClientMonitorScreen, VisBadge });
