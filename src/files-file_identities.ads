--  Non-following identities and revision snapshots for guarded operations.
package Files.File_Identities is
   --  Empty when the host cannot establish an identity. Never authorizes Undo.
   --  @param Path Entry to inspect without following symbolic links.
   --  @return Volume, host file ID and a stable generation field where the
   --  host provides one, or an empty token. Windows uses its full file ID and
   --  deliberately excludes creation time because NTFS may rewrite that time
   --  during a rename. This is not proof against deliberate same-owner forgery.
   function Token (Path : String) return String;

   --  @param Path Entry to inspect without following links.
   --  @param Include_Change_Time False for a root whose quarantine rename changes its ctime.
   --  @return Size, mode, ownership and precise modification/change times, or empty on failure.
   function Revision (Path : String; Include_Change_Time : Boolean := True) return String;
private
   Test_Identity_Unavailable : Boolean := False;
   pragma Atomic (Test_Identity_Unavailable);
end Files.File_Identities;
