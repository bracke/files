with GNAT.OS_Lib;
with Interfaces.C;

package Files.Directory_Rename_Access is
   type Context is limited private;

   --  Temporarily make a directory searchable for a rename, retaining the
   --  descriptor-bound original mode for restoration.
   --  @param Path Directory that the upcoming rename must traverse.
   --  @param State Held restoration state; released by Finish or Release.
   --  @return True when the path is ready or required no temporary change.
   function Prepare (Path : String; State : in out Context) return Boolean;

   --  Restore the mode captured by Prepare and release the held descriptor.
   --  @param State Restoration state returned by Prepare.
   --  @return True when restoration succeeded or no restoration was needed.
   function Finish (State : in out Context) return Boolean;

   --  Release held state without attempting a mode restoration.
   --  @param State Restoration state to discard.
   procedure Release (State : in out Context);

private
   type Context is limited record
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Mode       : Interfaces.C.unsigned := 0;
      Restore    : Boolean := False;
   end record;
end Files.Directory_Rename_Access;
