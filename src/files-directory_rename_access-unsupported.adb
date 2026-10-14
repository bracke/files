package body Files.Directory_Rename_Access is
   function Prepare (Path : String; State : in out Context) return Boolean is
      pragma Unreferenced (Path, State);
   begin
      return True;
   end Prepare;

   function Finish (State : in out Context) return Boolean is
      pragma Unreferenced (State);
   begin
      return True;
   end Finish;

   procedure Release (State : in out Context) is
      pragma Unreferenced (State);
   begin
      null;
   end Release;
end Files.Directory_Rename_Access;
