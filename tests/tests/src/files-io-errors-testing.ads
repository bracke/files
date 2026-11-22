--  What the suite reaches of Files.IO.Errors that is not part of its interface.
package Files.IO.Errors.Testing is

   --  @param Code An errno value from this host; zero means none.
   --  @param Fallback Key to answer when Code is no cause the user can act on.
   --  @return The key for Code's cause, or Fallback.
   function Key_For_Errno (Code : Integer; Fallback : String) return String;

   --  Record Code as though errno had held it.
   --  @param Code An errno value; zero records nothing.
   procedure Record_Code (Code : Integer);

   --  @param Fallback Key to answer when nothing specific was recorded.
   --  @return Key_For_Errno (Last_Code, Fallback).
   function Key_For_Last (Fallback : String) return String;

end Files.IO.Errors.Testing;
