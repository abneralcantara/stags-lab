import React, { useState } from 'react';

const styles = {
  app: {
    minHeight: '100vh',
    background: 'linear-gradient(135deg, #0f0f1a 0%, #1a1a2e 50%, #16213e 100%)',
    color: '#e0e0e0',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
  },
  header: {
    background: 'rgba(255,255,255,0.05)',
    borderBottom: '1px solid rgba(255,255,255,0.1)',
    padding: '16px 32px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  logo: {
    fontSize: '20px',
    fontWeight: '700',
    color: '#7c3aed',
    letterSpacing: '1px',
  },
  badge: {
    background: 'rgba(34,197,94,0.15)',
    color: '#22c55e',
    border: '1px solid rgba(34,197,94,0.3)',
    padding: '4px 12px',
    borderRadius: '20px',
    fontSize: '12px',
  },
  main: {
    maxWidth: '1100px',
    margin: '0 auto',
    padding: '40px 24px',
  },
  hero: {
    marginBottom: '40px',
  },
  heroTitle: {
    fontSize: '32px',
    fontWeight: '700',
    marginBottom: '8px',
  },
  heroSub: {
    color: '#9ca3af',
    fontSize: '16px',
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
    gap: '20px',
    marginBottom: '40px',
  },
  card: {
    background: 'rgba(255,255,255,0.04)',
    border: '1px solid rgba(255,255,255,0.08)',
    borderRadius: '12px',
    padding: '24px',
  },
  cardLabel: {
    fontSize: '12px',
    color: '#6b7280',
    textTransform: 'uppercase',
    letterSpacing: '1px',
    marginBottom: '8px',
  },
  cardValue: {
    fontSize: '28px',
    fontWeight: '700',
    color: '#7c3aed',
  },
  cardDesc: {
    fontSize: '13px',
    color: '#9ca3af',
    marginTop: '4px',
  },
  statusSection: {
    background: 'rgba(255,255,255,0.04)',
    border: '1px solid rgba(255,255,255,0.08)',
    borderRadius: '12px',
    padding: '24px',
  },
  statusTitle: {
    fontSize: '18px',
    fontWeight: '600',
    marginBottom: '16px',
  },
  serviceRow: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '10px 0',
    borderBottom: '1px solid rgba(255,255,255,0.05)',
  },
  dot: {
    width: '8px',
    height: '8px',
    borderRadius: '50%',
    background: '#22c55e',
    marginRight: '10px',
    display: 'inline-block',
  },
  serviceName: {
    display: 'flex',
    alignItems: 'center',
    fontSize: '14px',
  },
  serviceStatus: {
    fontSize: '13px',
    color: '#22c55e',
  },
};

const services = [
  { name: 'API Gateway', status: 'Operational' },
  { name: 'Authentication Service', status: 'Operational' },
  { name: 'Data Pipeline', status: 'Operational' },
  { name: 'Storage (S3)', status: 'Operational' },
  { name: 'CDN / CloudFront', status: 'Operational' },
  { name: 'Notification Service', status: 'Operational' },
];

function App() {
  const [expanded, setExpanded] = useState(false);

  return (
    <div style={styles.app}>
      <header style={styles.header}>
        <span style={styles.logo}>STAGS LAB</span>
        <span style={styles.badge}>All Systems Operational</span>
      </header>

      <main style={styles.main}>
        <div style={styles.hero}>
          <h1 style={styles.heroTitle}>Platform Dashboard</h1>
          <p style={styles.heroSub}>Internal cloud management portal — authorized personnel only</p>
        </div>

        <div style={styles.grid}>
          {[
            { label: 'Active Services', value: '6', desc: 'All healthy' },
            { label: 'Deployments Today', value: '20', desc: 'ECR images pushed' },
            { label: 'Uptime', value: '99.9%', desc: 'Last 30 days' },
            { label: 'Alerts', value: '0', desc: 'No active incidents' },
          ].map(card => (
            <div key={card.label} style={styles.card}>
              <div style={styles.cardLabel}>{card.label}</div>
              <div style={styles.cardValue}>{card.value}</div>
              <div style={styles.cardDesc}>{card.desc}</div>
            </div>
          ))}
        </div>

        <div style={styles.statusSection}>
          <div style={styles.statusTitle}>Service Status</div>
          {services.map((svc, i) => (
            <div key={svc.name} style={{
              ...styles.serviceRow,
              borderBottom: i === services.length - 1 ? 'none' : styles.serviceRow.borderBottom,
            }}>
              <span style={styles.serviceName}>
                <span style={styles.dot} />
                {svc.name}
              </span>
              <span style={styles.serviceStatus}>{svc.status}</span>
            </div>
          ))}
        </div>

        <div style={{ marginTop: '20px', textAlign: 'center' }}>
          <button
            onClick={() => setExpanded(!expanded)}
            style={{
              background: 'transparent',
              border: '1px solid rgba(124,58,237,0.4)',
              color: '#7c3aed',
              padding: '8px 20px',
              borderRadius: '8px',
              cursor: 'pointer',
              fontSize: '13px',
            }}
          >
            {expanded ? 'Hide' : 'Show'} deployment details
          </button>
          {expanded && (
            <div style={{ marginTop: '16px', color: '#6b7280', fontSize: '13px' }}>
              Environment: production | Region: us-east-1 | Build: {process.env.REACT_APP_REPO_NAME || 'local'}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

export default App;
