with Files.Background_Slots;
separate (Files_Suite.Info)
   procedure Test_Background_Slots_Serve_Many_Windows (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  More windows than the old fixed table of eight held.
      Windows : constant := 12;
      Failure : constant Natural := Natural'Last;

      function Measure (Path : String; Arguments : Natural) return Natural is (Path'Length + Arguments);
      function No_Result return Natural is (Failure);
      function Succeeded (Value : Natural) return Boolean is (Value /= Failure);

      package Slots is new Files.Background_Slots
        (Parameters  => Natural,
         Result      => Natural,
         Work        => Measure,
         Failed      => No_Result,
         Handed_Once => Succeeded);

      function Path_Of (Window : Positive) return String is ("file-" & Natural'Image (Window));

      Served : array (1 .. Windows) of Boolean := [others => False];
      Value  : Natural;
      Ready  : Boolean;
      Asked  : Boolean;
   begin
      for Window in 1 .. Windows loop
         Slots.Request (Slots.Requester (Window), Path_Of (Window), Window);
      end loop;
      --  Every window keeps its request until it is served: none is evicted
      --  by another's, so none has to ask again.
      for Attempt in Files_Suite.Support.Polling loop
         for Window in 1 .. Windows loop
            if not Served (Window) then
               Slots.Take (Slots.Requester (Window), Path_Of (Window), Window, Value, Ready, Asked);
               Assert (Asked, "window" & Natural'Image (Window) & " still has its request");
               if Ready then
                  Files_Suite.Support.Assert_Equal
                    (Value,
                     Path_Of (Window)'Length + Window,
                     "window" & Natural'Image (Window) & " gets its own result");
                  Served (Window) := True;
               end if;
            end if;
         end loop;
         exit when (for all Done of Served => Done);
      end loop;
      Assert ((for all Done of Served => Done), "every window is served");

      --  A result is asked for with its parameters: other parameters are
      --  another request.
      Slots.Request (1, Path_Of (1), 5);
      Slots.Take (1, Path_Of (1), 6, Value, Ready, Asked);
      Assert (not Asked and then not Ready, "a request with other parameters is not taken");
      --  A released window's slot goes.
      Slots.Release (1);
      Slots.Take (1, Path_Of (1), 5, Value, Ready, Asked);
      Assert (not Asked, "a released window has no request");
   end Test_Background_Slots_Serve_Many_Windows;
