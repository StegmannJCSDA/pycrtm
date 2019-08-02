#!/usr/bin/env python3
import configparser
import os, h5py, sys 
import numpy as np
from matplotlib import pyplot as plt
thisDir = os.path.dirname(os.path.abspath(__file__))
parentDir = os.path.dirname(thisDir)
sys.path.insert(0,parentDir)
from pycrtm import pycrtm
import time 
def main(coefficientPath, sensor_id):
    thisDir = os.path.dirname(os.path.abspath(__file__))
    cases = os.listdir( os.path.join(thisDir,'data') )
    cases.sort()
    salinity = 35.0
    zenithAngle = []
    azimuthAngle = []
    scanAngle = []
    solarAngle = []
    pressureLevels = []
    pressureLayers = []
    temperatureLayers =[]
    humidityLayers = []
    ozoneConcLayers =[]
    co2ConcLayers = []
    aerosolEffectiveRadius = []
    aerosolConcentration = []
    aerosolType = []
    cloudEffectiveRadius = []
    cloudConcentration = []
    cloudType = []
    cloudFraction =[]
    climatology = []
    surfaceTemperatures = []
    surfaceFractions = []
    LAI = []
    windSpeed = []
    windDirection = []
    n_absorbers = []
    landType = []
    soilType = []
    vegType = []
    waterType = []
    snowType = []
    iceType = []
    duplicateCases = []
    ii = 0
    for i in list(range(200)):
        duplicateCases.append(cases[ii])
        ii+=1
        if(ii==4): ii=0
 
    for c in duplicateCases:
        print(pycrtm.__doc__) 
        h5 = h5py.File(os.path.join(thisDir, 'data',c) , 'r')
        nChan = 22
        zenithAngle.append(h5['zenithAngle'][()])
        scanAngle.append(h5['scanAngle'][()])
        azimuthAngle.append( 999.9), 
        solarAngle.append(h5['solarAngle'][()])
        pressureLevels.append(h5['pressureLevels'])
        pressureLayers.append(h5['pressureLayers'])
        temperatureLayers.append(h5['temperatureLayers']) 
        humidityLayers.append(h5['humidityLayers']) 
        ozoneConcLayers.append(h5['ozoneConcLayers'])
        co2ConcLayers.append(h5['co2ConcLayers'])
        aerosolEffectiveRadius.append(h5['aerosolEffectiveRadius'])
        aerosolConcentration.append( h5['aerosolConcentration'] ) 
        aerosolType.append(h5['aerosolType'][()])
        cloudEffectiveRadius.append(h5['cloudEffectiveRadius']) 
        cloudConcentration.append(h5['cloudConcentration']) 
        cloudType.append(h5['cloudType'][()] ) 
        cloudFraction.append(h5['cloudFraction'])  
        climatology.append(h5['climatology'][()])
        surfaceTemperatures.append(h5['surfaceTemperatures']) 
        surfaceFractions.append(h5['surfaceFractions'] ) 
        LAI.append(h5['LAI'][()])
        windSpeed.append(h5['windSpeed10m'][()])
        windDirection.append(h5['windDirection10m'][()])
        n_absorbers.append(h5['n_absorbers'][()])
        landType.append(h5['landType'][()])
        soilType.append(h5['soilType'][()] ) 
        vegType.append(h5['vegType'][()] ) 
        waterType.append(h5['waterType'][()] )
        snowType.append(h5['snowType'][()] ) 
        iceType.append(h5['iceType'][()])
    print("GO CRTM!")
    start = time.time()
    """
    forwardTb, forwardTransmission,\
    forwardEmissivity = pycrtm.wrap_forward( coefficientPath, sensor_id,\
                        np.asarray(zenithAngle).T, np.asarray(scanAngle).T,np.asarray(azimuthAngle).T, np.asarray(solarAngle).T, nChan, \
                        np.asarray(pressureLevels).T, np.asarray(pressureLayers).T, np.asarray(temperatureLayers).T, np.asarray(humidityLayers).T, np.asarray(ozoneConcLayers).T,\
                        np.asarray(co2ConcLayers).T,\
                        np.asarray(aerosolEffectiveRadius).T, np.asarray(aerosolConcentration).T, np.asarray(aerosolType).T, \
                        np.asarray(cloudEffectiveRadius).T, np.asarray(cloudConcentration).T, np.asarray(cloudType).T, np.asarray(cloudFraction).T, np.asarray(climatology).T, \
                        np.asarray(surfaceTemperatures).T, np.asarray(surfaceFractions).T, np.asarray(LAI), salinity*np.ones(len(LAI)), np.asarray(windSpeed).T, np.asarray(windDirection).T, np.asarray(n_absorbers).T,\
                        np.asarray(landType), np.asarray(soilType), np.asarray(vegType), np.asarray(waterType), np.asarray(snowType), np.asarray(iceType), 1)
    """ 
    kTb, kTransmission, temperatureJacobian, humidityJacobian, ozoneJacobian,\
    kEmissivity = pycrtm.wrap_k_matrix( coefficientPath, sensor_id,\
                        np.asarray(zenithAngle).T, np.asarray(scanAngle).T,np.asarray(azimuthAngle).T, np.asarray(solarAngle).T, nChan, \
                        np.asarray(pressureLevels).T, np.asarray(pressureLayers).T, np.asarray(temperatureLayers).T, np.asarray(humidityLayers).T, np.asarray(ozoneConcLayers).T,\
                        np.asarray(co2ConcLayers).T,\
                        np.asarray(aerosolEffectiveRadius).T, np.asarray(aerosolConcentration).T, np.asarray(aerosolType).T, \
                        np.asarray(cloudEffectiveRadius).T, np.asarray(cloudConcentration).T, np.asarray(cloudType).T, np.asarray(cloudFraction).T, np.asarray(climatology).T, \
                        np.asarray(surfaceTemperatures).T, np.asarray(surfaceFractions).T, np.asarray(LAI), salinity*np.ones(len(LAI)), np.asarray(windSpeed).T, np.asarray(windDirection).T, np.asarray(n_absorbers).T,\
                        np.asarray(landType), np.asarray(soilType), np.asarray(vegType), np.asarray(waterType), np.asarray(snowType), np.asarray(iceType), 1)
 

    end = time.time()
    print('pycrtm took',end-start)
    wavenumbers = np.linspace(1,23,22)
    plt.figure()
    plt.plot(wavenumbers,forwardTb)
    plt.savefig(os.path.join(thisDir,c+'_spectrum_forward.png'))
    plt.figure()
    plt.plot(wavenumbers,forwardEmissivity)
    plt.savefig(os.path.join(thisDir,c+'_emissivity_forward.png')) 

    wavenumbers = np.linspace(1,23,22)
    plt.figure()
    plt.plot(wavenumbers,kTb)
    plt.savefig(os.path.join(thisDir,c+'_spectrum_k.png'))
    plt.figure()
    plt.plot(wavenumbers,kEmissivity)
    plt.savefig(os.path.join(thisDir,c+'_emissivity_k.png')) 





"""
        kTb, kTransmission,\
        temperatureJacobian,\
        humidityJacobian,\
        ozoneJacobian, kEmissivity = pycrtm.wrap_k_matrix( coefficientPath, sensor_id,\
                        np.asarray('zenithAngle'][()], np.asarray('scanAngle'][()], 999.9, np.asarray('solarAngle'][()], nChan,\
                        np.asarray('pressureLevels'], np.asarray('pressureLayers'], np.asarray('temperatureLayers'], np.asarray('humidityLayers'], np.asarray('ozoneConcLayers'],\
                        np.asarray('co2ConcLayers'],\
                        np.asarray('aerosolEffectiveRadius'], np.asarray('aerosolConcentration'], np.asarray('aerosolType'][()], \
                        np.asarray('cloudEffectiveRadius'], np.asarray('cloudConcentration'], np.asarray('cloudType'][()], np.asarray('cloudFraction'], np.asarray('climatology'][()], \
                        np.asarray('surfaceTemperatures'], np.asarray('surfaceFractions'], np.asarray('LAI'][()], salinity, np.asarray('windSpeed10m'][()], np.asarray('windDirection10m'][()], np.asarray('n_absorbers'][()],\
                        np.asarray('landType'][()], np.asarray('soilType'][()], np.asarray('vegType'][()], np.asarray('waterType'][()], np.asarray('snowType'][()], np.asarray('iceType'][()])
        

        wavenumbers = np.arange(22)
        diffK = kTb-np.asarray('Tb_atms'][0:22]
        diffKemis = kEmissivity-np.asarray('emissivity_atms'][0:22]
        
        if ( all(np.abs(diffKemis) <= 1e-10)  and all(np.abs(diffK) <= 1e-10) ):
            print ("Yay! we duplicated results from CRTM test program!")
        else:
            plt.figure()
            plt.plot(wavenumbers,kTb-np.asarray('Tb_atms'][0:22])
            plt.savefig(os.path.join(thisDir,c+'_spectrum_k_matrix.png'))

            plt.figure()
            plt.plot(wavenumbers,kEmissivity-np.asarray('emissivity_atms'][0:22])
            plt.savefig(os.path.join(thisDir,c+'_emissivity_k_matrix.png')) 
"""

if __name__ == "__main__":
    pathInfo = configparser.ConfigParser()
    pathInfo.read( os.path.join(parentDir,'crtm.cfg') ) 
    coefficientPath = pathInfo['CRTM']['coeffs_dir']
    sensor_id = 'atms_npp'
    main(coefficientPath, sensor_id)
 
