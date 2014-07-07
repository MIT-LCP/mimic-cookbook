create or replace FUNCTION merge25.GET_SAPS_FOR_PARAMETER (
    p_category IN VARCHAR2, p_val IN NUMBER)
return NUMBER IS
/*                                                                                              
  create_saps_formula.sql                                                                           
  
  Created on   : November 2008 by Mauricio Villarroel
  Last updated :
     $Author: djscott@ECG.MIT.EDU $
     $Date: 2010-05-18 11:58:55 -0400 (Tue, 18 May 2010) $
     $Rev: 113 $

  Using MIMIC2 version 2.5

 Function that returs the weight of a particular saps-I parameter
 This is used in the calculation for saps-I score.
 Formula given by Mohammed Saeed, some units have been converted.
 
 Calucation taken from: 
 * GALL, JEAN-ROGER LE MD, et al. A simplified acute physiology
   score for ICU patients, Critical Care,
   November 1984 - Volume 12 - Issue 11
   
   http://journals.lww.com/ccmjournal/Abstract/1984/11000/A_simplified_acute_physiology_score_for_ICU.12.aspx   
   
*/

   retValue NUMBER := -1;

BEGIN

    IF (p_val IS NULL) THEN
      RETURN retValue;
    END IF;

    IF p_category = 'HR' THEN

        IF p_val < 40 THEN
            retValue := 4;
        ELSIF p_val <= 54 THEN
            retValue := 3;
        ELSIF p_val <= 69 THEN
            retValue := 2;
        ELSIF p_val <= 109 THEN
            retValue := 0;
        ELSIF p_val <= 139 THEN
            retValue := 2;
        ELSIF p_val <= 179 THEN
            retValue := 3;
        ELSIF p_val >= 180 THEN
            retValue := 4;
        END IF;

    ELSIF p_category = 'TEMPERATURE' THEN

        IF p_val < 30 THEN
            retValue := 4;
        ELSIF p_val < 32 THEN
            retValue := 3;
        ELSIF p_val < 34 THEN
            retValue := 2;
        ELSIF p_val < 36 THEN
            retValue := 1;
        ELSIF p_val <= 38.4 THEN
            retValue := 0;
        ELSIF p_val <= 38.9 THEN
            retValue := 1;
        ELSIF p_val < 41 THEN
            retValue := 3;
        ELSIF p_val >= 41 THEN
            retValue := 4;
        END IF;

    ELSIF p_category = 'SYS ABP' THEN

        IF p_val < 55 THEN
            retValue := 4;
        ELSIF p_val <= 79 THEN
            retValue := 2;
        ELSIF p_val <= 149 THEN
            retValue := 0;
        ELSIF p_val <= 189 THEN
            retValue := 2;
        ELSIF p_val >= 190 THEN
            retValue := 4;
        END IF;

    ELSIF p_category = 'VENTILATED_RESP' THEN

        retValue := 3;

    ELSIF p_category = 'SPONTANEOUS_RESP' THEN

        IF p_val < 6 THEN
            retValue := 4;
        ELSIF p_val <= 9 THEN
            retValue := 2;
        ELSIF p_val <= 11 THEN
            retValue := 1;
        ELSIF p_val <= 24 THEN
            retValue := 0;
        ELSIF p_val <= 34 THEN
            retValue := 1;
        ELSIF p_val <= 49 THEN
            retValue := 3;
        ELSIF p_val >= 50 THEN
            retValue := 4;
        END IF;

    ELSIF p_category = 'BUN' THEN

        IF p_val < 10 THEN
            retValue := 1;
        ELSIF p_val < 21 THEN
            retValue := 0;
        ELSIF p_val <= 81 THEN
            retValue := 1;
        ELSIF p_val <= 101 THEN
            retValue := 2;
        ELSIF p_val < 154 THEN
            retValue := 3;
        ELSIF p_val >= 154 THEN
            retValue := 4;
        END IF;

    ELSIF p_category = 'HCT' THEN

        IF p_val < 20 THEN
            retValue := 4;
        ELSIF p_val < 30 THEN
            retValue := 2;
        ELSIF p_val < 46 THEN
            retValue := 0;
        ELSIF p_val < 50 THEN
            retValue := 1;
        ELSIF p_val < 60 THEN
            retValue := 2;
        ELSIF p_val >= 60 THEN
            retValue := 4;
        END IF;

    ELSIF p_category = 'WBC' THEN

        IF p_val < 1 THEN
            retValue := 4;
        ELSIF p_val < 3 THEN
            retValue := 2;
        ELSIF p_val < 15 THEN
            retValue := 0;
        ELSIF p_val < 20 THEN
            retValue := 1;
        ELSIF p_val < 40 THEN
            retValue := 2;
        ELSIF p_val >= 40 THEN
            retValue := 4;
        END IF;

    ELSIF p_category = 'GLUCOSE' THEN

        IF p_val < 29 THEN
            retValue := 4;
        ELSIF p_val <= 49 THEN
            retValue := 3;
        ELSIF p_val <= 69 THEN
            retValue := 2;
        ELSIF p_val <= 249 THEN
            retValue := 0;
        ELSIF p_val <= 499 THEN
            retValue := 1;
        ELSIF p_val <= 799 THEN
            retValue := 3;
        ELSIF p_val >= 800 THEN
            retValue := 4;
        END IF;

    ELSIF p_category = 'POTASSIUM' THEN

        IF p_val < 2.5 THEN
            retValue := 4;
        ELSIF p_val <= 2.9 THEN
            retValue := 2;
        ELSIF p_val <= 3.4 THEN
            retValue := 1;
        ELSIF p_val <= 5.4 THEN
            retValue := 0;
        ELSIF p_val <= 5.9 THEN
            retValue := 1;
        ELSIF p_val <= 6.9 THEN
            retValue := 3;
        ELSIF p_val >= 7 THEN
            retValue := 4;
        END IF;

    ELSIF p_category = 'SODIUM' THEN

        IF p_val < 110 THEN
            retValue := 4;
        ELSIF p_val < 120 THEN
            retValue := 3;
        ELSIF p_val <= 129 THEN
            retValue := 2;
        ELSIF p_val  <= 150 THEN
            retValue := 0;
        ELSIF p_val <= 155 THEN
            retValue := 1;
        ELSIF p_val <= 160 THEN
            retValue := 2;
        ELSIF p_val <= 179 THEN
            retValue := 3;
        ELSIF p_val >= 180 THEN
            retValue := 4;
        END IF;

    ELSIF p_category = 'HCO3' THEN

        IF p_val < 5 THEN
            retValue := 4;
        ELSIF p_val < 10 THEN
            retValue := 3;
        ELSIF p_val < 20 THEN
            retValue := 1;
        ELSIF p_val < 30 THEN
            retValue := 0;
        ELSIF p_val < 40 THEN
            retValue := 1;
        ELSIF p_val >= 40 THEN
            retValue := 3;
        END IF;

    ELSIF p_category = 'GCS' THEN

        IF p_val < 4 THEN
            retValue := 4;
        ELSIF p_val < 7 THEN
            retValue := 3;
        ELSIF p_val < 10 THEN
            retValue := 2;
        ELSIF p_val < 13 THEN
            retValue := 1;
        ELSIF p_val >= 13 THEN
            retValue := 0;
        END IF;

    ELSIF p_category = 'AGE' THEN

        IF p_val <= 45 THEN
            retValue := 0;
        ELSIF p_val < 55 THEN
            retValue := 1;
        ELSIF p_val <= 65 THEN
            retValue := 2;
        ELSIF p_val <= 75 THEN
            retValue := 3;
        ELSIF p_val > 75 THEN
            retValue := 4;
        END IF;

    ELSIF p_category = 'URINE' THEN

        IF p_val < 0.2 THEN
            retValue := 4;
        ELSIF p_val <= 0.49 THEN
            retValue := 3;
        ELSIF p_val <= 0.69 THEN
            retValue := 2;
        ELSIF p_val <= 3.49 THEN
            retValue := 0;
        ELSIF p_val <= 4.99 THEN
            retValue := 1;
        ELSIF p_val >= 5 THEN
            retValue := 2;
        END IF;

    END IF;

    return retValue;

END;

 
 