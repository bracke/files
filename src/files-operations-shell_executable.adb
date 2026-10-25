separate (Files.Operations)
--  These stay public because callers and tests ask for them, but the answer is
--  Hostkit's: which shell, and how it wants a command introduced, is one question
--  asked in one place, not re-derived per crate.
function Shell_Executable return String is
begin
   return Hostkit.Shell.Executable;
end Shell_Executable;
