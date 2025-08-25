import { GeistMono } from "geist/font/mono";
import { GeistSans } from "geist/font/sans";
import "~~/styles/globals.css";

export default function OpSwapLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${GeistSans.variable} ${GeistMono.variable}`} suppressHydrationWarning>
      <body>
        <div className="min-h-screen">{children}</div>
      </body>
    </html>
  );
}
