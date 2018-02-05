\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{compactslide}
\LoadClass[semcolor,semrot,landscape]{seminar}

\RequirePackage{fancybox}
\RequirePackage{color}
\RequirePackage{graphicx}

\setlength{\slidewidth}{10in}
\setlength{\slideheight}{7in}
\renewcommand{\slidetopmargin}{.3in}
\renewcommand{\slidebottommargin}{.3in}
\renewcommand{\slideleftmargin}{.1in}
\renewcommand{\sliderightmargin}{.1in}

\newpagestyle{compactslide}
{}
{\tiny \textit{\thetitle}\small \hfil \thepage}
\pagestyle{compactslide}
\newslideframe{noframe}{\boxput{\vspace{11in}}{#1}}
\slideframe{noframe}

\renewcommand{\printlandscape}{\special{landscape}}
\special{! TeXDict begin /landplus90{true}store end }

\renewcommand{\familydefault}{\sfdefault}
\centerslidesfalse

\newcommand{\heading}[1]{%
  \begin{center}%
    \large\bf%
    \shadowbox{#1}
  \end{center}%
  \vspace{1ex minus 1ex}}

\newcommand{\includeslidegraphics}[2]{%
  \begin{center}%
    \includegraphics[width=#2\textwidth]{#1}
  \end{center}%
}

\newcommand{\titleslide}{\begin{slide}\maketitle\end{slide}}
\newcommand{\questionslide}{%
  \begin{slide}\begin{center}
  {\LARGE Questions?}
  \end{center}\end{slide}}
\newenvironment{textslide}[1]
  {\begin{slide}\heading{#1}\begin{itemize}}
  {\end{itemize}\end{slide}}

