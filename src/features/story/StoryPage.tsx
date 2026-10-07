import { PageFrame } from '../../app/Shell'
import { navigate } from '../../app/router'
import { SCENES, STORY_TOTAL } from './script'
import { StoryPlayer } from './StoryPlayer'

const presenting = import.meta.env.VITE_STORY_DEMO === 'true'

/** The story on its own page, so it can be linked to and presented. */
export function StoryPage() {
  return (
    <PageFrame
      title="Ana’s payday on Sweldo"
      // Presentation mode keeps the whole player on one phone screen.
      description={presenting ? undefined : `A ${Math.round(STORY_TOTAL)}-second story: a locked payroll, a payday countdown, a one-tap claim, and pay in pesos. Space plays and pauses; the arrow keys skip scenes.`}
    >
      <StoryPlayer autoplay={presenting} finishedLabel="Set up payroll" onFinishedAction={() => navigate('/employer')} />
      <h2 className="t-title m0" style={{ marginTop: 'var(--s-xl)' }}>In words</h2>
      <ol className="story-words-list">
        {SCENES.map((scene, index) => (
          <li key={index}>
            <span className="t-figures t-muted">{index + 1}.</span>
            <span className="t-body">{scene.caption}</span>
          </li>
        ))}
      </ol>
    </PageFrame>
  )
}
