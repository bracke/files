separate (Files.File_System)
function Detect_Directory_Change
  (Before_State : Directory_Signature;
   Path         : String)
   return Directory_Change_Result
is
   After_State : constant Directory_Signature := Directory_State (Path);
   --  An unknown signature on either side counts as a change.
   Changed     : constant Boolean := not Same_State (Before_State, After_State);
begin
   return
     (Changed      => Changed,
      Before_State => Before_State,
      After_State  => After_State,
      Error_Key    =>
        (if After_State.Exists then Null_Unbounded_String else To_Unbounded_String ("error.directory.load")));
end Detect_Directory_Change;
