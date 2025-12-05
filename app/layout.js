import "./globals.css";

export const metadata = {
  title: "A股智投 AI",
  description: "极简主义 A股 AI 分析工具",
};

export default function RootLayout({ children }) {
  return (
    <html lang="zh-CN">
      <body className="bg-[#f5f5f7] text-gray-900 antialiased selection:bg-blue-500 selection:text-white">
        {children}
      </body>
    </html>
  );
}
