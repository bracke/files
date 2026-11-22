with Files.Model.Recent;
separate (Files.Operations)
function Launch_Open_Actions
  (Model   : in out Files.Model.Window_Model;
   Actions : Files.Desktop_Applications.Open_Action_Vectors.Vector;
   Paths   : Files.Types.String_Vectors.Vector)
   return Operation_Result
is
   --  The path Actions (Index) opens, as a failure names it.
   function Path_Of (Index : Positive) return String is
     (if Paths.Is_Empty then ""
      elsif Natural (Paths.Length) = Natural (Actions.Length) then To_String (Paths (Index))
      else To_String (Paths.First_Element));

   First_Exit_Status : Integer := 0;
begin
   --  Every executable is checked before any is started.
   for Index in Actions.First_Index .. Actions.Last_Index loop
      if not Open_Action_Executable_Is_Available (Actions (Index)) then
         Files.Model.Set_Error (Model, "error.open_action.executable_missing");
         return
           Make_Result
             (Operation_Failed,
              "error.open_action.executable_missing",
              Path_Of (Index),
              Actions (Index),
              Attempted => False,
              Found     => False);
      end if;
   end loop;

   for Index in Actions.First_Index .. Actions.Last_Index loop
      declare
         Exit_Status : Integer := 0;
         Failure_Key : Unbounded_String;
         --  Detached: Spawn_OK says whether the launch (or the wrapper
         --  shell of a system-fallback handler) started, not how the
         --  application ends.
         Spawn_OK    : constant Boolean :=
           Execute_Open_Action (Actions (Index), Exit_Status, Failure_Key, Detach => True);
         --  "Path too long" when that is why, not "failed to execute".
         Error_Key   : constant String :=
           (if Length (Failure_Key) > 0 then To_String (Failure_Key) else "error.open_action.execution");
      begin
         if not Spawn_OK then
            Files.Model.Set_Error (Model, Error_Key);
            return
              Make_Result
                (Operation_Failed,
                 Error_Key,
                 Path_Of (Index),
                 Actions (Index),
                 Attempted   => True,
                 Found       => True,
                 Exit_Known  => False,
                 Exit_Status => Exit_Status);
         end if;
         if Index = Actions.First_Index then
            First_Exit_Status := Exit_Status;
         end if;
      end;
   end loop;

   --  All started: what they opened joins the recent list, freshest last.
   for Path of Paths loop
      Files.Model.Recent.Note_Recent_Open (Model, To_String (Path));
   end loop;
   Files.Model.Set_Error (Model, "");
   return
     Make_Result
       (Operation_Action_Executed,
        Path        => Path_Of (Actions.First_Index),
        Action      => Actions.First_Element,
        Attempted   => True,
        Found       => True,
        --  Started and let go, so there is no exit status.
        Exit_Known  => False,
        Exit_Status => First_Exit_Status);
end Launch_Open_Actions;
