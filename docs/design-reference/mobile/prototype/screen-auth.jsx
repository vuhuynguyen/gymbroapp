// GymBro Mobile — Auth flow: login / register / join-by-invite.
// Mirrors features/auth + the join-gymbro side panel (invite code).

function Segmented({ options, value, onChange }) {
  return (
    <div style={{
      display: 'flex', background: 'var(--inv-grey-25)', borderRadius: 'var(--gb-r-sm)', padding: 4, gap: 4,
    }}>
      {options.map(o => {
        const on = value === o.id;
        return (
          <button key={o.id} onClick={() => onChange(o.id)} style={{
            flex: 1, height: 40, border: 'none', borderRadius: 10, cursor: 'pointer',
            font: '700 14px var(--inv-font-sans)', letterSpacing: '-0.01em',
            background: on ? 'var(--inv-surface-base)' : 'transparent',
            color: on ? 'var(--gb-ink)' : 'var(--inv-grey-500)',
            boxShadow: on ? 'var(--gb-shadow-sm)' : 'none', transition: 'all .15s',
          }}>{o.label}</button>
        );
      })}
    </div>
  );
}

function AuthScreen({ platform, onAuthed }) {
  const [mode, setMode] = React.useState('login'); // login | signup | invite
  const [focus, setFocus] = React.useState(null);
  const [code, setCode] = React.useState(['K', '7', 'P', '2', 'W', '', '', '']);

  const tab = mode === 'invite' ? 'login' : mode;

  return (
    <div style={{
      height: '100%', background: 'var(--inv-surface-base)', display: 'flex', flexDirection: 'column',
      paddingTop: safeTop(platform), overflowY: 'auto',
    }}>
      {/* Brand header */}
      <div style={{ padding: '26px 24px 10px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
        <BrandMark size={62} radius={20} glyph />
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: '-0.03em', color: 'var(--gb-ink)' }}>GymBro</div>
          <div style={{ fontSize: 14, color: 'var(--inv-grey-500)', marginTop: 2, whiteSpace: 'nowrap' }}>Coach. Train. Track.</div>
        </div>
      </div>

      {mode !== 'invite' ? (
        <div style={{ padding: '14px 24px 28px', display: 'flex', flexDirection: 'column', gap: 18 }}>
          <Segmented options={[{ id: 'login', label: 'Log in' }, { id: 'signup', label: 'Sign up' }]}
            value={tab} onChange={setMode} />

          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            {mode === 'signup' && (
              <Field label="Full name" value="Alex Rivera" icon="user" focused={focus === 'name'}
                onFocus={() => setFocus('name')} />
            )}
            <Field label="Email" value="alex@trainwith.me" icon="mail" focused={focus === 'email'}
              onFocus={() => setFocus('email')} />
            <Field label="Password" type="password" value="catchmeup" icon="lock" focused={focus === 'pw'}
              onFocus={() => setFocus('pw')} />
          </div>

          {mode === 'login' && (
            <div style={{ textAlign: 'right', marginTop: -4 }}>
              <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--inv-primary-600)' }}>Forgot password?</span>
            </div>
          )}

          <GbButton full size="lg" label={mode === 'login' ? 'Log in' : 'Create account'}
            iconRight="arrowR" onClick={onAuthed} />

          <div style={{ display: 'flex', alignItems: 'center', gap: 12, color: 'var(--inv-grey-400)' }}>
            <span style={{ flex: 1, height: 1, background: 'var(--inv-border-card)' }} />
            <span style={{ fontSize: 12, fontWeight: 600 }}>or</span>
            <span style={{ flex: 1, height: 1, background: 'var(--inv-border-card)' }} />
          </div>

          <GbButton full outlined severity="secondary" icon="ticket" label="Join with an invite code"
            onClick={() => setMode('invite')} />

          <p style={{ fontSize: 12, color: 'var(--inv-grey-400)', textAlign: 'center', lineHeight: 1.5, margin: 0 }}>
            By continuing you agree to GymBro's Terms & Privacy Policy.
          </p>
        </div>
      ) : (
        <div style={{ padding: '14px 24px 28px', display: 'flex', flexDirection: 'column', gap: 20 }}>
          <button onClick={() => setMode('login')} style={{
            display: 'inline-flex', alignItems: 'center', gap: 6, background: 'none', border: 'none',
            cursor: 'pointer', color: 'var(--inv-grey-600)', font: '600 14px var(--inv-font-sans)', padding: 0,
          }}>
            <Icon name="chevL" size={18} /> Back
          </button>

          <div>
            <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--inv-grey-900)', letterSpacing: '-0.01em' }}>Join your coach</div>
            <div style={{ fontSize: 14, color: 'var(--inv-grey-500)', marginTop: 4, lineHeight: 1.5 }}>
              Enter the 8-character invite code your coach shared. Codes are single-use and expire after 7 days.
            </div>
          </div>

          <div style={{ display: 'flex', gap: 6, justifyContent: 'space-between' }}>
            {code.map((ch, i) => (
              <div key={i} style={{
                flex: 1, height: 54, borderRadius: 'var(--gb-r-sm)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 21, fontWeight: 800, color: 'var(--gb-ink)',
                background: ch ? 'var(--inv-primary-0)' : 'var(--inv-grey-0)',
                border: `1.5px solid ${ch ? 'var(--inv-primary-300)' : 'var(--inv-border-field)'}`,
                boxShadow: ch ? '0 0 0 3px rgba(59,130,246,0.1)' : 'none',
              }} className="gb-num">{ch || ''}</div>
            ))}
          </div>

          <div style={{
            display: 'flex', gap: 10, alignItems: 'flex-start', padding: 14, borderRadius: 12,
            background: 'var(--inv-secondary-0)', border: '1px solid var(--inv-primary-25)',
          }}>
            <Icon name="user" size={18} color="var(--inv-primary-600)" style={{ marginTop: 1 }} />
            <div style={{ fontSize: 13, color: 'var(--inv-grey-700)', lineHeight: 1.5 }}>
              You'll join <strong style={{ color: 'var(--inv-grey-900)' }}>Coach Morgan's</strong> workspace as a client.
              Your own training history stays private.
            </div>
          </div>

          <GbButton full size="lg" label="Join workspace" icon="check" onClick={onAuthed} />
        </div>
      )}
    </div>
  );
}

Object.assign(window, { AuthScreen });
