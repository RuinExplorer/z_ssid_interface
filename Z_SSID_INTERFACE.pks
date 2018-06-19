CREATE OR REPLACE PACKAGE BANINST1.z_ssid_interface
AS
    /****************************************************************************
       NAME:    z_ssid_interface
       PURPOSE: This package provides functionality to interact with the SSID
                field in Banner and update it from the Utah State Office of
                Education SSID Verification web service.
    ****************************************************************************/
    PROCEDURE p_get_banner_ssid (p_banner_id VARCHAR2, p_ssid OUT VARCHAR2);

    PROCEDURE p_set_banner_ssid (p_banner_id    VARCHAR2,
                                 p_ssid         VARCHAR2,
                                 p_user_name    VARCHAR2);

    PROCEDURE p_demo_service_call;

    PROCEDURE p_debug_service_call;

    PROCEDURE p_post_service_call (p_last_name           VARCHAR2,
                                   p_first_name          VARCHAR2,
                                   p_birth_date          DATE,
                                   p_gender              VARCHAR2,
                                   p_ssid         IN OUT VARCHAR2,
                                   p_status          OUT VARCHAR2,
                                   p_reason          OUT VARCHAR2);

    PROCEDURE p_ssid_service_call (p_last_name           VARCHAR2,
                                   p_first_name          VARCHAR2,
                                   p_birth_date          DATE,
                                   p_gender              VARCHAR2,
                                   p_ssid         IN OUT VARCHAR2,
                                   p_status          OUT VARCHAR2,
                                   p_reason          OUT VARCHAR2);

    PROCEDURE p_batch_ssid_update_v1 (
        p_term_code          VARCHAR2,
        p_update_mode        VARCHAR2 DEFAULT 'N',
        p_check_existing     VARCHAR2 DEFAULT 'N',
        p_submit_existing    VARCHAR2 DEFAULT 'N');

    PROCEDURE p_post_ssid_vBeta (p_last_name        VARCHAR2,
                                 p_first_name       VARCHAR2,
                                 p_birth_date       DATE,
                                 p_gender           VARCHAR2,
                                 p_response     OUT VARCHAR2,
                                 p_status       OUT VARCHAR2,
                                 p_reason       OUT VARCHAR2);

    PROCEDURE p_batch_ssid_update_vBeta (
        p_term_code         VARCHAR2,
        p_update_mode       VARCHAR2 DEFAULT 'N',
        p_check_existing    VARCHAR2 DEFAULT 'N');
END z_ssid_interface;
/