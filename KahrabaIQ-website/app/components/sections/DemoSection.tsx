import Image from "next/image";
import type React from "react";
import type { SiteContent } from "../../../types/site";
import { SectionHeader } from "../ui/SectionHeader";

function Frame({ className = "", children }: { className?: string; children: React.ReactNode }) {
  return (
    <article className={`mockup-frame ${className}`}>
      <div className="frame-bar"><span /><span /><span /></div>
      <div className="frame-body">{children}</div>
    </article>
  );
}

function DashboardMockup({ content }: { content: SiteContent }) {
  return (
    <Frame className="dashboard-frame">
      <div className="dash-top"><span>{content.mockup.live}</span><strong>{content.mockup.safe}</strong></div>
      <div className="metric-row">{content.mockup.metrics.map(({ label, value }) => <div key={label}><span>{label}</span><strong>{value}</strong></div>)}</div>
      <div className="dash-main">
        <div className="chart" aria-label={content.accessibility.chart}>{content.mockup.chartBars.map((height, index) => <i key={index} style={{ height: `${height}%` }} />)}</div>
        <div className="device-list">{content.mockup.devices.map((device) => <div key={device.name}><span>{device.name}</span><b className={device.tone === "warn" ? "warn" : ""}>{device.state}</b></div>)}</div>
      </div>
    </Frame>
  );
}

function HardwareMockup({ label, chip, imageAlt }: { label: string; chip: string; imageAlt: string }) {
  return (
    <Frame className="hardware-frame">
      <div className="hardware-caption">
        <span className="chip">{chip}</span>
        <strong>{label}</strong>
      </div>
      <div className="board">
        <Image src="/prototype-hardware.jpg" alt={imageAlt} fill sizes="(max-width: 768px) 100vw, 33vw" className="prototype-photo" />
      </div>
    </Frame>
  );
}

function MobilePrototypeGallery({ content }: { content: SiteContent }) {
  return (
    <Frame className="mobile-prototype-frame">
      <div className="hardware-caption">
        <span className="chip">{content.mockup.mobilePrototypeChip}</span>
        <strong>{content.mockup.mobilePrototypeLabel}</strong>
      </div>
      <div className="mobile-prototype-grid">
        {content.mockup.mobilePrototypeImages.map((image, index) => (
          <div className="app-screen" key={image.src} style={{ "--screen-offset": index } as React.CSSProperties}>
            <Image src={image.src} alt={image.alt} fill sizes="(max-width: 768px) 44vw, 18vw" className="app-screen-image" />
          </div>
        ))}
      </div>
    </Frame>
  );
}

export function DemoSection({ content }: { content: SiteContent }) {
  return (
    <section id="demo" className="section showcase" aria-labelledby="demo-title">
      <div className="container">
        <SectionHeader {...content.sections.demo} id="demo-title" />
        <div className="showcase-grid">
          <DashboardMockup content={content} />
          <HardwareMockup label={content.mockup.hardwareLabel} chip={content.mockup.hardwareChip} imageAlt={content.mockup.hardwareImageAlt} />
          <MobilePrototypeGallery content={content} />
        </div>
      </div>
    </section>
  );
}
