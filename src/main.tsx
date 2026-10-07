import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './styles/tokens.css'
import './styles/base.css'
import './styles/ui.css'
import App from './App.tsx'

if (import.meta.env.VITE_STORY_DEMO === 'true' && !window.location.hash) window.location.hash = '/story'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
