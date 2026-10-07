import type { ReactNode } from 'react'
import { Signal, Wifi } from 'lucide-react'

export const SCREEN = { width: 390, height: 844 }
const BEZEL = 13
export const FRAME = { width: SCREEN.width + BEZEL * 2, height: SCREEN.height + BEZEL * 2 }

const BUTTONS = [
  { left: true, top: 150, height: 34 },
  { left: true, top: 210, height: 64 },
  { left: true, top: 288, height: 64 },
  { left: false, top: 240, height: 100 },
]

/** An iPhone-shaped frame (390 × 844 points) with a Dynamic Island, side buttons, status bar and home indicator. */
export function IPhoneFrame({ screen, time = '9:41' }: { screen: ReactNode; time?: string }) {
  return (
    <div className="iphone" style={{ width: FRAME.width, height: FRAME.height }}>
      {BUTTONS.map((button, index) => (
        <span key={index} className="iphone-side-button" style={{ top: button.top, height: button.height, [button.left ? 'left' : 'right']: -3 }} />
      ))}
      <div className="iphone-body">
        <div className="iphone-screen" style={{ width: SCREEN.width, height: SCREEN.height }}>
          <div className="iphone-screen-content">{screen}</div>
          <div className="iphone-status">
            <span>{time}</span>
            <span className="iphone-status-spacer" />
            <Signal size={17} strokeWidth={2} />
            <Wifi size={17} strokeWidth={2} style={{ marginLeft: 5 }} />
            <span className="iphone-battery"><span /></span>
          </div>
          <span className="iphone-island" />
          <span className="iphone-home" />
        </div>
      </div>
    </div>
  )
}
