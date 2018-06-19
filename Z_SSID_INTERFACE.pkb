/* Formatted on 6/19/2018 1:25:23 PM (QP5 v5.313) */
CREATE OR REPLACE PACKAGE BODY BANINST1.z_ssid_interface
AS
    /****************************************************************************
       NAME:       z_ssid_interface
       CHANGE LOG:
           20141017  Carl Ellsworth, USU   Created this package
                                              p_get_banner_ssid
                                              p_set_banner_ssid
           20141106  Carl Ellsworth, USU   added p_demo_service_call
           20141107  Carl Ellsworth, USU   added p_ssid_service_call, global
                                           variables, generalized package for
                                           use outside of USU
           20141113  Carl Ellsworth, USU   added p_batch_ssid_update
           20150427  Carl Ellsworth, USU   added p_submit_existing parameter
                                           allowing users to indicate if they want
                                           to include the Banner SSID in the
                                           web service call
           20150428  Carl Ellsworth, USU   added an error and reason field to the
                                           log file for better followup on errors
           20150428  Carl Ellsworth, USU   added URL encoding to handle names with
                                           internal spaces and special characters
           20150429  Carl Ellsworth, USU   added p_post_service_request as an
                                           example of the same process using
                                           POST instead of GET
           20150430  Carl Ellsworth, USU   corrected a sequencing bug causing
                     Joe Belnap, UVU       status code and response to be lost
                                           when the message body was empty
           20161014  Carl Ellsworth, USU   added character limit on
                                           UTL_HTTP.read_text() calls to eliminate
                                           character string buffer too small errors
           20170912  Carl Ellsworth, USU   added procedure for vBeta version of
                                           USBE SSID webservice
           20170925  Carl Ellsworth, USU   added function to get SSID from the JSON
                                           response from the web service.
                                           added procedure p_batch_ssid_update_vBeta
                                           to mirror v1 behavior on the new version
           20170926  Carl Ellsworth, USU   removed extranious parameters from vBeta
                                           procedure and calls
           20171211  Carl Ellsworth, USU   updated vBeta to v2
           20180619  Carl Ellsworth, USU   added overloaded p_set_banner_ssid
    ****************************************************************************/

    gv_ssid_adid_value   VARCHAR2 (4) := 'SSID';    --code for ssid on gtvadid
    gv_api_key           VARCHAR2 (256)
                             := '';
    gv_wallet_path       VARCHAR2 (256) := 'file:/u01/app/oracle/WALLETS';
    gv_wallet_password   VARCHAR2 (256) := '';
    gv_folder            VARCHAR2 (64) := 'RCDE';              --output folder

    PROCEDURE p_implementation
    --This is a dummy procedure used to capture the steps needed to prepare
    --  your Oracle database to connect with the state web service.
    AS
    BEGIN
        /* On the Oracle Database side, here are the steps for security
          1. Add domain to public ACL

          BEGIN
           DBMS_NETWORK_ACL_ADMIN.assign_acl (
             acl         => 'public.xml',
             host        => 'ssidapi.schools.utah.gov',
             lower_port  => null,
             upper_port  => null);
           COMMIT;
          END;
          /

          select * from DBA_NETWORK_ACLS
          select * from DBA_NETWORK_ACL_PRIVILEGES
          select * from USER_NETWORK_ACL_PRIVILEGES

          2. Import webservice SSL cert into oracle wallet

          - view cert using: openssl s_client -showcerts -connect ssidapi.schools.utah.gov:443
          - launch Oracle Wallet Manager (OWM) on the cluster and add the certs to wallet stored in: /u01/oracle/WALLETS/ewallet.p12

          3. specify the wallet in PLSQL block before interacting with the webs ervice
          use UTL_HTTP.SET_WALLET('file:/u02/app/oracle/racdb/wallet/', 'wallet_password');
        */


        /* Once the ACL, SSL, and wallet are all dealt with, use this script to test
          DECLARE
             --turn DBMS OUTPUT on
             v_ssid   VARCHAR2 (256) := NULL;
          BEGIN
             BANINST1.Z_SSID_INTERFACE.P_DEBUG_SERVICE_CALL ();
          END;
        */
        NULL;
    END;

    PROCEDURE p_get_banner_ssid (p_banner_id VARCHAR2, p_ssid OUT VARCHAR2)
    --This procedure retrieves an existing SSID from Banner
    AS
        v_ssid   goradid.goradid_additional_id%TYPE;
        v_date   goradid.goradid_activity_date%TYPE;
    BEGIN
        SELECT goradid_additional_id, goradid_activity_date
          INTO v_ssid, v_date
          FROM goradid
         WHERE     goradid_adid_code = gv_ssid_adid_value
               AND goradid_pidm =
                   (SELECT spriden_pidm
                      FROM spriden
                     WHERE     spriden_change_ind IS NULL
                           AND spriden_id = p_banner_id);

        p_ssid := v_ssid;

        DBMS_OUTPUT.put_line (
            p_banner_id || ' retuns SSID ' || v_ssid || ' created ' || v_date);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            DBMS_OUTPUT.put_line (p_banner_id || ' returns no SSID on file');
        WHEN TOO_MANY_ROWS
        THEN
            DBMS_OUTPUT.put_line (
                   p_banner_id
                || ' returns more than one SSID and needs to be corrected');
    END;

    PROCEDURE p_set_banner_ssid (p_banner_id    VARCHAR2,
                                 p_ssid         VARCHAR2,
                                 p_user_name    VARCHAR2)
    --This procedure sets an SSID in Banner for a given Banner ID
    AS
        v_pidm   goradid.goradid_pidm%TYPE;
    BEGIN
        SELECT spriden_pidm
          INTO v_pidm
          FROM spriden
         WHERE spriden_change_ind IS NULL AND spriden_id = p_banner_id;

        IF p_ssid IS NOT NULL
        THEN
            INSERT INTO goradid (goradid_pidm,
                                 goradid_additional_id,
                                 goradid_adid_code,
                                 goradid_user_id,
                                 goradid_activity_date,
                                 goradid_data_origin)
                 VALUES (v_pidm,
                         p_ssid,
                         gv_ssid_adid_value,
                         p_user_name,
                         SYSDATE,
                         'Z_SSID_INTERFACE');

            DBMS_OUTPUT.put_line (
                p_ssid || ' - This SSID SUCCESSFULY ADDED to ' || p_banner_id);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            DBMS_OUTPUT.put_line (p_banner_id || ' not found');
        WHEN DUP_VAL_ON_INDEX
        THEN
            DBMS_OUTPUT.put_line (
                p_ssid || ' - This SSID already exists in the system');
    END;

    PROCEDURE p_set_banner_ssid (p_pidm         NUMBER,
                                 p_ssid         VARCHAR2,
                                 p_user_name    VARCHAR2)
    --This procedure sets an SSID in Banner for a given Banner pidm.
    AS
        v_pidm   goradid.goradid_pidm%TYPE;
    BEGIN
        SELECT spriden_pidm
          INTO v_pidm
          FROM spriden
         WHERE spriden_change_ind IS NULL AND spriden_pidm = p_pidm;

        IF p_ssid IS NOT NULL AND v_pidm IS NOT NULL
        THEN
            INSERT INTO goradid (goradid_pidm,
                                 goradid_additional_id,
                                 goradid_adid_code,
                                 goradid_user_id,
                                 goradid_activity_date,
                                 goradid_data_origin)
                 VALUES (v_pidm,
                         p_ssid,
                         gv_ssid_adid_value,
                         p_user_name,
                         SYSDATE,
                         'Z_SSID_INTERFACE');

            DBMS_OUTPUT.put_line (
                p_ssid || ' - This SSID SUCCESSFULY ADDED to pidm ' || v_pidm);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            DBMS_OUTPUT.put_line (p_pidm || ' not found');
        WHEN DUP_VAL_ON_INDEX
        THEN
            DBMS_OUTPUT.put_line (
                p_ssid || ' - This SSID already exists in the system');
    END;

    PROCEDURE p_demo_service_call
    --This is a demo web service call from pl/sql that doesn't require
    --  SSL. This allows for a developer to debug certain aspects
    --  eliminating SSL from the equation.
    AS
        v_param_list      VARCHAR2 (512);
        v_http_request    UTL_HTTP.req;
        v_http_response   UTL_HTTP.resp;
        v_response_text   VARCHAR2 (32767);
    BEGIN
        --service input parameters
        v_param_list := 'FromCurrency=USD' || '&' || 'ToCurrency=INR';

        --prepare request
        v_http_request :=
            UTL_HTTP.begin_request (
                'http://www.webservicex.net/currencyconvertor.asmx/ConversionRate',
                'POST',
                'HTTP/1.1');

        --set header attributes
        UTL_HTTP.set_header (v_http_request,
                             'Content-Type',
                             'application/x-www-form-urlencoded');
        UTL_HTTP.set_header (v_http_request,
                             'Content-Length',
                             LENGTH (v_param_list));

        --set input parameters
        UTL_HTTP.write_text (v_http_request, v_param_list);

        --get response and obtrain received value
        v_http_response := UTL_HTTP.get_response (v_http_request);

        UTL_HTTP.read_text (v_http_response, v_response_text);

        DBMS_OUTPUT.put_line (v_response_text);

        --finalizing
        UTL_HTTP.end_response (v_http_response);
    EXCEPTION
        WHEN UTL_HTTP.end_of_body
        THEN
            UTL_HTTP.end_response (v_http_response);
    END p_demo_service_call;

    PROCEDURE p_debug_service_call
    --This procedure uses dummy parameters provided by the state to test
    --  connectivity to the state web service.
    AS
        v_http_request    UTL_HTTP.req;
        v_http_response   UTL_HTTP.resp;
        v_response_text   VARCHAR2 (4096);
    BEGIN
        --specifiy the oracle wallet containing the SSL certificate
        UTL_HTTP.set_wallet (gv_wallet_path, gv_wallet_password);

        v_http_request :=
            UTL_HTTP.begin_request (
                'https://ssidapi.schools.utah.gov/ssid/1/Student/Test/1994-01-01/M',
                'GET',
                'HTTP/1.1');

        --set header Authorization parameters
        UTL_HTTP.set_header (v_http_request, 'Authorization', gv_api_key);

        --set header attributes
        UTL_HTTP.set_header (v_http_request,
                             'Content-Type',
                             'application/json');

        --get response and obtain received value
        v_http_response := UTL_HTTP.get_response (v_http_request);

        -- DEBUG Entries

        DBMS_OUTPUT.put_line (
            'HTTP response status code: ' || v_http_response.status_code);
        DBMS_OUTPUT.put_line (
            'HTTP response reason phrase: ' || v_http_response.reason_phrase);

        UTL_HTTP.read_text (v_http_response, v_response_text);
        DBMS_OUTPUT.put_line (v_response_text);

        --finalizing
        UTL_HTTP.end_response (v_http_response);
    EXCEPTION
        WHEN UTL_HTTP.end_of_body
        THEN
            UTL_HTTP.end_response (v_http_response);
    END;

    PROCEDURE p_post_service_call (p_last_name           VARCHAR2,
                                   p_first_name          VARCHAR2,
                                   p_birth_date          DATE,
                                   p_gender              VARCHAR2,
                                   p_ssid         IN OUT VARCHAR2,
                                   p_status          OUT VARCHAR2,
                                   p_reason          OUT VARCHAR2)
    --This procedure is a POST based clone of p_ssid_service_call. This was
    --  added as example code for schools who needed to use POST over GET.
    --  One key aspect of using POST is the Content-Length is required.
    AS
        v_formatted_date   VARCHAR2 (32);
        v_payload          VARCHAR2 (1024);
        v_http_request     UTL_HTTP.req;
        v_http_response    UTL_HTTP.resp;
        v_response_text    VARCHAR2 (4096);
    BEGIN
        IF p_ssid IS NULL
        THEN
            p_ssid := '0';
        END IF;

        --date format specified in USOE web service documentation
        v_formatted_date := TO_CHAR (p_birth_date, 'YYYY-MM-DD');

        --specifiy the oracle wallet containing the SSL certificate
        UTL_HTTP.set_wallet (gv_wallet_path, gv_wallet_password);

        --prepare request
        v_http_request :=
            UTL_HTTP.begin_request (
                --use of utl_url.escapse handles internal spaces and special characters
                UTL_URL.escape ('https://ssidapi.schools.utah.gov/ssid/'),
                'POST',
                'HTTP/1.1');
        /* 20150428 State Web Serive now handles "Multiple Records found." errors
           by adding '?mult=true' to the end of the request. However, the response
           is true json and a standard response is not. For now, leaving multiples
           as an exception case to have corrrected by staff. -Carl
        */

        --build payload from parameters
        v_payload :=
               '{"LastName":"'
            || TRIM (p_last_name)
            || '","FirstName":"'
            || TRIM (p_first_name)
            || '","BirthDate":"'
            || v_formatted_date
            || '","Gender":"'
            || p_gender
            || '"}';

        --set header authorization parameters
        UTL_HTTP.set_header (v_http_request, 'Authorization', gv_api_key);

        --set header attributes
        UTL_HTTP.set_header (v_http_request,
                             'Content-Type',
                             'application/json');

        UTL_HTTP.set_header (v_http_request, 'Cache-Control', 'no-cache');

        UTL_HTTP.set_header (v_http_request,
                             'Content-Length',
                             LENGTH (v_payload));

        --set payload of request
        UTL_HTTP.write_text (v_http_request, v_payload);

        --get response and obtain received value
        v_http_response := UTL_HTTP.get_response (v_http_request);

        -- DEBUG Entries
        /*
        DBMS_OUTPUT.put_line ('HTTP response status code: ' || v_http_response.status_code);
        DBMS_OUTPUT.put_line ('HTTP response reason phrase: ' || v_http_response.reason_phrase);
        */

        --populate out parameters
        p_status := SUBSTR (v_http_response.status_code, 0, 128);
        p_reason := SUBSTR (v_http_response.reason_phrase, 0, 512);

        --self contained block for exception handling when message body may be empty
        BEGIN
            UTL_HTTP.read_text (v_http_response, v_response_text, 4096);
            --DBMS_OUTPUT.put_line (v_response_text);

            --populate out parameters
            p_ssid := SUBSTR (v_response_text, 1, 128);

            --finalizing
            UTL_HTTP.end_response (v_http_response);
        EXCEPTION
            WHEN UTL_HTTP.end_of_body
            THEN
                UTL_HTTP.end_response (v_http_response);
        END;
    END p_post_service_call;

    PROCEDURE p_ssid_service_call (p_last_name           VARCHAR2,
                                   p_first_name          VARCHAR2,
                                   p_birth_date          DATE,
                                   p_gender              VARCHAR2,
                                   p_ssid         IN OUT VARCHAR2,
                                   p_status          OUT VARCHAR2,
                                   p_reason          OUT VARCHAR2)
    --This procedure is the primary method of interacting with the
    --  state web service to retrieve SSIDs. It is used by
    --  p_batch_ssid_update.
    AS
        v_formatted_date   VARCHAR2 (32);
        v_http_request     UTL_HTTP.req;
        v_http_response    UTL_HTTP.resp;
        v_response_text    VARCHAR2 (4096);
    BEGIN
        IF p_ssid IS NULL
        THEN
            p_ssid := '0';
        END IF;

        --date format specified in USOE web service documentation
        v_formatted_date := TO_CHAR (p_birth_date, 'YYYY-MM-DD');

        --specifiy the oracle wallet containing the SSL certificate
        UTL_HTTP.set_wallet (gv_wallet_path, gv_wallet_password);

        --prepare request
        v_http_request :=
            UTL_HTTP.begin_request (
                --use of utl_url.escapse handles internal spaces and special characters
                UTL_URL.escape (
                       'https://ssidapi.schools.utah.gov/ssid/'
                    || p_ssid --SSID or LEA Student Number, 0 when not avilable
                    || '/'
                    || TRIM (p_last_name)   --trim extraneous spaces from name
                    || '/'
                    || TRIM (p_first_name)  --trim extraneous spaces from name
                    || '/'
                    || v_formatted_date
                    || '/'
                    || p_gender),
                'GET',
                'HTTP/1.1');
        /* 20150428 State Web Serive now handles "Multiple Records found." errors
           by adding '?mult=true' to the end of the request. However, the response
           is true json and a standard response is not. For now, leaving multiples
           as an exception case to have corrrected by staff. -Carl
        */

        --set header authorization parameters
        UTL_HTTP.set_header (v_http_request, 'Authorization', gv_api_key);

        --set header attributes
        UTL_HTTP.set_header (v_http_request,
                             'Content-Type',
                             'application/json');

        UTL_HTTP.set_header (v_http_request, 'Cache-Control', 'no-cache');

        --get response and obtain received value
        v_http_response := UTL_HTTP.get_response (v_http_request);

        -- DEBUG Entries
        /*
        DBMS_OUTPUT.put_line ('HTTP response status code: ' || v_http_response.status_code);
        DBMS_OUTPUT.put_line ('HTTP response reason phrase: ' || v_http_response.reason_phrase);
        */

        --populate out parameters
        p_status := SUBSTR (v_http_response.status_code, 0, 128);
        p_reason := SUBSTR (v_http_response.reason_phrase, 0, 512);

        --self contained block for exception handling when message body may be empty
        BEGIN
            UTL_HTTP.read_text (v_http_response, v_response_text, 4096);
            --DBMS_OUTPUT.put_line (v_response_text);

            --populate out parameters
            p_ssid := SUBSTR (v_response_text, 1, 128);

            --finalizing
            UTL_HTTP.end_response (v_http_response);
        EXCEPTION
            WHEN UTL_HTTP.end_of_body
            THEN
                UTL_HTTP.end_response (v_http_response);
        END;
    END p_ssid_service_call;

    PROCEDURE p_batch_ssid_update_v1 (
        p_term_code          VARCHAR2,
        p_update_mode        VARCHAR2 DEFAULT 'N',
        p_check_existing     VARCHAR2 DEFAULT 'N',
        p_submit_existing    VARCHAR2 DEFAULT 'N')
    --This proceudre is what allows batch update to all concurrent enrollment
    --  students so their SSID as recorded at the state is reflected in Banner.
    AS
        CURSOR cur_students
        IS
            --this cursor is the population we are going to check for SSIDs
            --   and add them if they don't exist
            --replace this curosr with your own criteria
            SELECT DISTINCT spriden_id,
                            goradid_additional_id,
                            spriden_last_name,
                            spriden_first_name,
                            spbpers_birth_date,
                            spbpers_sex
              FROM sfrstcr
                   JOIN spriden
                       ON     spriden_pidm = sfrstcr_pidm
                          AND spriden_change_ind IS NULL
                   LEFT JOIN goradid
                       ON     goradid_pidm = sfrstcr_pidm
                          AND goradid_adid_code = gv_ssid_adid_value
                   LEFT JOIN spbpers ON spbpers_pidm = sfrstcr_pidm
                   JOIN sgbstdn alpha
                       ON     sgbstdn_pidm = sfrstcr_pidm
                          AND sgbstdn_styp_code = 'H'   --concurrent indicator
                          AND sgbstdn_term_code_eff =
                              (SELECT MAX (bravo.sgbstdn_term_code_eff)
                                 FROM sgbstdn bravo
                                WHERE     bravo.sgbstdn_pidm =
                                          alpha.sgbstdn_pidm
                                      AND bravo.sgbstdn_term_code_eff <=
                                          p_term_code)
             WHERE sfrstcr_term_code = p_term_code;

        v_ssid                 VARCHAR2 (128) := NULL;
        v_status               VARCHAR2 (128) := NULL;
        v_error                VARCHAR2 (128) := NULL;
        v_reason               VARCHAR2 (512) := NULL;
        flag_update_mode       BOOLEAN := FALSE;
        flag_check_existing    BOOLEAN := FALSE;
        flag_submit_existing   BOOLEAN := FALSE;

        --PROCESSING VARIABLES
        v_id                   UTL_FILE.file_type;
        v_filedata             VARCHAR2 (20000);
        v_delim                CHAR := CHR (44);
        v_header      CONSTANT VARCHAR2 (512)
            :=    'Banner_ID'
               || v_delim
               || 'Banner_SSID'
               || v_delim
               || 'State_SSID'
               || v_delim
               || 'Last_Name'
               || v_delim
               || 'First_Name'
               || v_delim
               || 'Birthdate'
               || v_delim
               || 'Gender'
               || v_delim
               || 'Action'
               || v_delim
               || 'Status'
               || v_delim
               || 'Error'
               || v_delim
               || 'Reason' ;
    BEGIN
        --set audit_mode, check_existing, and submit_existing flags
        IF (    p_update_mode IS NOT NULL
            AND p_check_existing IS NOT NULL
            AND p_submit_existing IS NOT NULL)
        THEN
            IF (UPPER (SUBSTR (p_update_mode, 1, 1)) = 'Y')
            THEN
                flag_update_mode := TRUE;
            END IF;

            IF (UPPER (SUBSTR (p_check_existing, 1, 1)) = 'Y')
            THEN
                flag_check_existing := TRUE;
            END IF;

            IF (UPPER (SUBSTR (p_submit_existing, 1, 1)) = 'Y')
            THEN
                flag_submit_existing := TRUE;
            END IF;
        END IF;

        --open log file
        v_id :=
            UTL_FILE.fopen (gv_folder,
                            'StateSSIDsync' || p_term_code || '.csv',
                            'w',
                            20000);

        --print header record to log file
        --DBMS_OUTPUT.put_line (v_header);
        UTL_FILE.put_line (v_id, v_header);


        FOR i_student IN cur_students
        LOOP
            v_ssid := NULL;
            v_status := NULL;
            v_error := NULL;
            v_reason := NULL;

            IF i_student.goradid_additional_id IS NULL
            THEN
                --look for ssid
                p_ssid_service_call (i_student.spriden_last_name,
                                     i_student.spriden_first_name,
                                     i_student.spbpers_birth_date,
                                     UPPER (i_student.spbpers_sex),
                                     v_ssid,
                                     v_status,
                                     v_reason);
            ELSIF (flag_check_existing AND NOT flag_submit_existing)
            THEN
                --look for SSID, but don't submit current ssid
                p_ssid_service_call (i_student.spriden_last_name,
                                     i_student.spriden_first_name,
                                     i_student.spbpers_birth_date,
                                     UPPER (i_student.spbpers_sex),
                                     v_ssid,
                                     v_status,
                                     v_reason);
            ELSIF (flag_check_existing AND flag_submit_existing)
            THEN
                --look for SSID and submit current Banner SSID
                v_ssid := i_student.goradid_additional_id;

                p_ssid_service_call (i_student.spriden_last_name,
                                     i_student.spriden_first_name,
                                     i_student.spbpers_birth_date,
                                     UPPER (i_student.spbpers_sex),
                                     v_ssid,
                                     v_status,
                                     v_reason);
            END IF;

            --status of 200 is successful web service submission and response
            IF (v_status <> 200)
            THEN
                --this removes any non-ssid data from the v_ssid variable into an error field
                v_error := v_ssid;
                v_ssid := NULL;
            END IF;

            IF (v_ssid IS NOT NULL AND flag_update_mode)
            THEN
                --update Banner with the SSID returned from the State web service
                p_set_banner_ssid (p_banner_id   => i_student.spriden_id,
                                   p_ssid        => v_ssid,
                                   p_user_name   => 'Z_SSID_INTERFACE');
                --print to log file
                v_filedata :=
                    (   i_student.spriden_id
                     || v_delim
                     || i_student.goradid_additional_id
                     || v_delim
                     || v_ssid
                     || v_delim
                     || i_student.spriden_last_name
                     || v_delim
                     || i_student.spriden_first_name
                     || v_delim
                     || TO_CHAR (i_student.spbpers_birth_date, 'YYYY-MM-DD')
                     || v_delim
                     || i_student.spbpers_sex
                     || v_delim
                     || 'UPDATED'
                     || v_delim
                     || v_status
                     || v_delim
                     || v_error
                     || v_delim
                     || v_reason);

                --DBMS_OUTPUT.put_line (v_filedata);
                UTL_FILE.put_line (v_id, v_filedata);
            ELSE
                --in this case, only print an entry in the log file
                v_filedata :=
                    (   i_student.spriden_id
                     || v_delim
                     || i_student.goradid_additional_id
                     || v_delim
                     || v_ssid
                     || v_delim
                     || i_student.spriden_last_name
                     || v_delim
                     || i_student.spriden_first_name
                     || v_delim
                     || TO_CHAR (i_student.spbpers_birth_date, 'YYYY-MM-DD')
                     || v_delim
                     || i_student.spbpers_sex
                     || v_delim
                     || 'NONE'
                     || v_delim
                     || v_status
                     || v_delim
                     || v_error
                     || v_delim
                     || v_reason);

                --DBMS_OUTPUT.put_line (v_filedata);
                UTL_FILE.put_line (v_id, v_filedata);
            END IF;
        END LOOP;

        --close log file
        UTL_FILE.fclose (v_id);
    END;

    PROCEDURE p_post_ssid_vBeta (p_last_name        VARCHAR2,
                                 p_first_name       VARCHAR2,
                                 p_birth_date       DATE,
                                 p_gender           VARCHAR2,
                                 p_response     OUT VARCHAR2,
                                 p_status       OUT VARCHAR2,
                                 p_reason       OUT VARCHAR2)
    AS
        v_formatted_date              VARCHAR2 (32);
        v_payload                     VARCHAR2 (4096);
        v_http_request                UTL_HTTP.req;
        v_http_response               UTL_HTTP.resp;
        v_response_text               VARCHAR2 (4096);
        v_service_location   CONSTANT VARCHAR2 (60 CHAR)
            := 'https://ssidapi.schools.utah.gov/ssid/v2/Lookup' ;
    BEGIN
        --date format specified in USBE web service documentation
        v_formatted_date := TO_CHAR (p_birth_date, 'YYYY-MM-DD');

        --specifiy the oracle wallet containing the SSL certificate
        UTL_HTTP.set_wallet (gv_wallet_path, gv_wallet_password);

        --prepare request
        v_http_request :=
            UTL_HTTP.begin_request ( --use of utl_url.escapse handles internal spaces and special characters
                                    UTL_URL.escape (v_service_location),
                                    'POST',
                                    'HTTP/1.1');

        --build payload from parameters
        v_payload :=
               '{"LastName":"'
            || TRIM (p_last_name)
            || '","FirstName":"'
            || TRIM (p_first_name)
            || '","BirthDate":"'
            || v_formatted_date
            || '","Gender":"'
            || p_gender
            || '","Fields":"all"}';

        --set header authorization parameters
        UTL_HTTP.set_header (v_http_request, 'Authorization', gv_api_key);

        --set header attributes
        UTL_HTTP.set_header (v_http_request,
                             'Content-Type',
                             'application/json');

        UTL_HTTP.set_header (v_http_request, 'Cache-Control', 'no-cache');

        --POST calls require Content-Length set
        UTL_HTTP.set_header (v_http_request,
                             'Content-Length',
                             LENGTH (v_payload));

        --set payload of request
        UTL_HTTP.write_text (v_http_request, v_payload);

        --get response and obtain received value
        v_http_response := UTL_HTTP.get_response (v_http_request);

        -- DEBUG Entries
        DBMS_OUTPUT.put_line (
            'HTTP response status code: ' || v_http_response.status_code);
        DBMS_OUTPUT.put_line (
            'HTTP response reason phrase: ' || v_http_response.reason_phrase);


        --populate out parameters
        p_status := SUBSTR (v_http_response.status_code, 0, 128);
        p_reason := SUBSTR (v_http_response.reason_phrase, 0, 512);

        --self contained block for exception handling when message body may be empty
        BEGIN
            UTL_HTTP.read_text (v_http_response, v_response_text, 4096);

            -- DEBUG ENTRIES
            DBMS_OUTPUT.put_line ('HTTP response body: ' || v_response_text);

            --populate out parameters
            p_response := SUBSTR (v_response_text, 1, 4096);

            --finalizing
            UTL_HTTP.end_response (v_http_response);
        EXCEPTION
            WHEN UTL_HTTP.end_of_body
            THEN
                UTL_HTTP.end_response (v_http_response);
        END;
    END p_post_ssid_vBeta;

    FUNCTION f_get_ssid_from_json (p_json_string VARCHAR2)
        RETURN VARCHAR2
    AS
        v_ssid   VARCHAR2 (16);
    BEGIN
        DBMS_OUTPUT.put_line (p_json_string);

        WITH json AS (SELECT p_json_string doc FROM DUAL)
        SELECT MIN (ssid)
          INTO v_ssid
          FROM JSON_TABLE ((SELECT doc FROM json), '$[*]'
                           COLUMNS (ssid VARCHAR2 (16) PATH '$.ssid'));

        RETURN v_ssid;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (p_json_string);
            RAISE;
    END;

    PROCEDURE p_batch_ssid_update_vBeta (
        p_term_code         VARCHAR2,
        p_update_mode       VARCHAR2 DEFAULT 'N',
        p_check_existing    VARCHAR2 DEFAULT 'N')
    --This proceudre is what allows batch update to all concurrent enrollment
    --  students so their SSID as recorded at the state is reflected in Banner.
    AS
        CURSOR cur_students
        IS
            --this cursor is the population we are going to check for SSIDs
            --   and add them if they don't exist
            --replace this curosr with your own criteria
            SELECT DISTINCT spriden_id,
                            goradid_additional_id,
                            spriden_last_name,
                            spriden_first_name,
                            spbpers_birth_date,
                            spbpers_sex
              FROM sfrstcr
                   JOIN spriden
                       ON     spriden_pidm = sfrstcr_pidm
                          AND spriden_change_ind IS NULL
                   LEFT JOIN goradid
                       ON     goradid_pidm = sfrstcr_pidm
                          AND goradid_adid_code = gv_ssid_adid_value
                   LEFT JOIN spbpers ON spbpers_pidm = sfrstcr_pidm
                   JOIN sgbstdn alpha
                       ON     sgbstdn_pidm = sfrstcr_pidm
                          AND sgbstdn_styp_code = 'H'   --concurrent indicator
                          AND sgbstdn_term_code_eff =
                              (SELECT MAX (bravo.sgbstdn_term_code_eff)
                                 FROM sgbstdn bravo
                                WHERE     bravo.sgbstdn_pidm =
                                          alpha.sgbstdn_pidm
                                      AND bravo.sgbstdn_term_code_eff <=
                                          p_term_code)
             WHERE sfrstcr_term_code = p_term_code;

        v_response            VARCHAR2 (4096) := NULL;
        v_banner_ssid         VARCHAR2 (50) := NULL;
        v_ssid                VARCHAR2 (50) := NULL;
        v_status              VARCHAR2 (128) := NULL;
        v_error               VARCHAR2 (4096) := NULL;
        v_reason              VARCHAR2 (512) := NULL;
        flag_update_mode      BOOLEAN := FALSE;
        flag_check_existing   BOOLEAN := FALSE;

        --PROCESSING VARIABLES
        v_id                  UTL_FILE.file_type;
        v_filedata            VARCHAR2 (20000);
        v_delim               CHAR := CHR (44);
        v_header     CONSTANT VARCHAR2 (512)
            :=    'Banner_ID'
               || v_delim
               || 'Banner_SSID'
               || v_delim
               || 'State_SSID'
               || v_delim
               || 'Last_Name'
               || v_delim
               || 'First_Name'
               || v_delim
               || 'Birthdate'
               || v_delim
               || 'Gender'
               || v_delim
               || 'Action'
               || v_delim
               || 'Status'
               || v_delim
               || 'Error'
               || v_delim
               || 'Reason' ;
    BEGIN
        --set audit_mode, check_existing flags
        IF (p_update_mode IS NOT NULL AND p_check_existing IS NOT NULL)
        THEN
            IF (UPPER (SUBSTR (p_update_mode, 1, 1)) = 'Y')
            THEN
                flag_update_mode := TRUE;
            END IF;

            IF (UPPER (SUBSTR (p_check_existing, 1, 1)) = 'Y')
            THEN
                flag_check_existing := TRUE;
            END IF;
        END IF;

        --open log file
        v_id :=
            UTL_FILE.fopen (gv_folder,
                            'StateSSIDsync' || p_term_code || '.csv',
                            'w',
                            20000);

        --print header record to log file
        --DBMS_OUTPUT.put_line (v_header);
        UTL_FILE.put_line (v_id, v_header);

        FOR i_student IN cur_students
        LOOP
            v_banner_ssid := i_student.goradid_additional_id;
            v_response := NULL;
            v_ssid := NULL;
            v_status := NULL;
            v_error := NULL;
            v_reason := NULL;

            IF (v_banner_ssid IS NULL OR flag_check_existing)
            THEN
                p_post_ssid_vBeta (i_student.spriden_last_name,
                                   i_student.spriden_first_name,
                                   i_student.spbpers_birth_date,
                                   UPPER (i_student.spbpers_sex),
                                   v_response,
                                   v_status,
                                   v_reason);
            --vBeta has no option to submit existing ssids from our system
            END IF;

            --status of 200 is successful web service submission and response
            IF (v_status = 200)
            THEN
                v_ssid := f_get_ssid_from_json (v_response);
            ELSE
                --this removes any non-ssid data from the v_ssid variable into an error field
                v_error := v_response;
                v_ssid := NULL;
            END IF;

            IF (v_banner_ssid IS NOT NULL AND v_ssid = v_banner_ssid)
            THEN
                --print to log file
                v_filedata :=
                    (   i_student.spriden_id
                     || v_delim
                     || i_student.goradid_additional_id
                     || v_delim
                     || v_ssid
                     || v_delim
                     || i_student.spriden_last_name
                     || v_delim
                     || i_student.spriden_first_name
                     || v_delim
                     || TO_CHAR (i_student.spbpers_birth_date, 'YYYY-MM-DD')
                     || v_delim
                     || i_student.spbpers_sex
                     || v_delim
                     || 'NO UPDATE REQUIRED'
                     || v_delim
                     || v_status
                     || v_delim
                     || v_error
                     || v_delim
                     || v_reason);

                --DBMS_OUTPUT.put_line (v_filedata);
                UTL_FILE.put_line (v_id, v_filedata);
            ELSIF (v_ssid IS NOT NULL AND flag_update_mode)
            THEN
                --update Banner with the SSID returned from the State web service
                p_set_banner_ssid (p_banner_id   => i_student.spriden_id,
                                   p_ssid        => v_ssid,
                                   p_user_name   => 'Z_SSID_INTERFACE');
                --print to log file
                v_filedata :=
                    (   i_student.spriden_id
                     || v_delim
                     || i_student.goradid_additional_id
                     || v_delim
                     || v_ssid
                     || v_delim
                     || i_student.spriden_last_name
                     || v_delim
                     || i_student.spriden_first_name
                     || v_delim
                     || TO_CHAR (i_student.spbpers_birth_date, 'YYYY-MM-DD')
                     || v_delim
                     || i_student.spbpers_sex
                     || v_delim
                     || 'SSID UPDATED'
                     || v_delim
                     || v_status
                     || v_delim
                     || v_error
                     || v_delim
                     || v_reason);

                --DBMS_OUTPUT.put_line (v_filedata);
                UTL_FILE.put_line (v_id, v_filedata);
            ELSE
                --in this case, only print an entry in the log file
                v_filedata :=
                    (   i_student.spriden_id
                     || v_delim
                     || i_student.goradid_additional_id
                     || v_delim
                     || v_ssid
                     || v_delim
                     || i_student.spriden_last_name
                     || v_delim
                     || i_student.spriden_first_name
                     || v_delim
                     || TO_CHAR (i_student.spbpers_birth_date, 'YYYY-MM-DD')
                     || v_delim
                     || i_student.spbpers_sex
                     || v_delim
                     || 'NO ACTION TAKEN'
                     || v_delim
                     || v_status
                     || v_delim
                     || v_error
                     || v_delim
                     || v_reason);

                --DBMS_OUTPUT.put_line (v_filedata);
                UTL_FILE.put_line (v_id, v_filedata);
            END IF;
        END LOOP;

        --close log file
        UTL_FILE.fclose (v_id);
    END;
END z_ssid_interface;
/