--  The repository under test, for the few checks that read its sources or
--  shipped files rather than exercise behaviour. Every lookup fails loudly
--  when what it reads is not there, so such a check can never pass by not
--  finding its subject.
package Files_Suite.Repository is

   --  The repository root: the current directory or its nearest ancestor that
   --  holds files.gpr. Raises Program_Error when there is none.
   --
   --  @return The absolute path of the repository root.
   function Root return String;

   --  A repository-relative path made absolute against Root.
   --
   --  @param Relative Path below the root, with forward slashes.
   --  @return The absolute path.
   function Path (Relative : String) return String;

   --  Whether a repository-relative path names an ordinary file.
   --
   --  @param Relative Path below the root.
   --  @return True when the file exists.
   function File_Exists (Relative : String) return Boolean;

   --  Whether a repository file contains Pattern. In Ada sources and project
   --  files (.ads, .adb, .gpr) comments are ignored, so a pattern that only
   --  survives in a comment does not count. Raises Program_Error when the file
   --  does not exist.
   --
   --  @param Relative Path below the root.
   --  @param Pattern Literal text to look for.
   --  @return True when Pattern occurs outside comments.
   function File_Contains (Relative : String; Pattern : String) return Boolean;

   --  Whether any file under src/ contains Pattern outside Ada comments.
   --  Raises Program_Error when src/ does not exist.
   --
   --  @param Pattern Literal text to look for.
   --  @return True when some source contains Pattern outside comments.
   function Source_Contains (Pattern : String) return Boolean;

   --  Text with every Ada comment removed: from "--" to the end of its line,
   --  unless the "--" is inside a string or character literal.
   --
   --  @param Text Ada source text.
   --  @return The text without comments; line breaks are kept.
   function Without_Comments (Text : String) return String;

end Files_Suite.Repository;
