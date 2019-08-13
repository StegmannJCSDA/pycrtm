#!/usr/bin/env python3
import configparser
import os, h5py,sys 
import numpy as np
from matplotlib import pyplot as plt
thisDir = os.path.dirname(os.path.abspath(__file__))
parentDir = os.path.dirname(thisDir)
sys.path.insert(0,parentDir)
from pycrtm import pycrtm

def main(coefficientPath, sensor_id):
    salinity = 33.0
    thisDir = os.path.dirname(os.path.abspath(__file__))
    cases = os.listdir( os.path.join(thisDir,'data') ) 
    cases.sort()
    for c in cases:
        h5 = h5py.File(os.path.join(thisDir, 'data', c) , 'r')
        nChan = np.asarray(h5['Tb']).shape[0] 


        forwardTb, forwardTransmission,\
        forwardEmissivity = pycrtm.wrap_forward( coefficientPath, sensor_id,\
                        h5['zenithAngle'][()], h5['scanAngle'][()], 999.9, np.asarray([100.0,0.0]).reshape([1,2]),2001,1,1, nChan, \
                        np.asarray(h5['pressureLevels']).reshape([1,93]),np.asarray(h5['pressureLayers']).reshape([1,92]), np.asarray(h5['temperatureLayers']).reshape([1,92]), np.asarray(h5['humidityLayers']).reshape([1,92]), np.asarray(h5['ozoneConcLayers']).reshape([1,92]),\
                        np.asarray(h5['co2ConcLayers']).reshape([1,92]),\
                        np.asarray(h5['aerosolEffectiveRadius']).reshape([1,92,1]), np.asarray(h5['aerosolConcentration']).reshape([1,92,1]), h5['aerosolType'][()], \
                        np.asarray(h5['cloudEffectiveRadius']).reshape([1,92,1]), np.asarray(h5['cloudConcentration']).reshape([1,92,1]), h5['cloudType'][()], np.asarray(h5['cloudFraction']).reshape([1,92]), h5['climatology'][()], \
                        np.asarray(h5['surfaceTemperatures']).reshape([1,4]), np.asarray(h5['surfaceFractions']).reshape([1,4]), h5['LAI'][()], salinity, np.float(5.0), h5['windDirection10m'][()], h5['n_absorbers'][()],\
                        h5['landType'][()], h5['soilType'][()], h5['vegType'][()], h5['waterType'][()], h5['snowType'][()], h5['iceType'][()], 1 )

        kTb, kTransmission,\
        temperatureJacobian,\
        humidityJacobian,\
        ozoneJacobian, kEmissivity = pycrtm.wrap_k_matrix( coefficientPath, sensor_id,\
                        h5['zenithAngle'][()], h5['scanAngle'][()], 999.9, np.asarray([100.0,0.0]).reshape([1,2]), 2001,1,1, nChan, \
                        np.asarray(h5['pressureLevels']).reshape([1,93]),np.asarray(h5['pressureLayers']).reshape([1,92]), np.asarray(h5['temperatureLayers']).reshape([1,92]), np.asarray(h5['humidityLayers']).reshape([1,92]), np.asarray(h5['ozoneConcLayers']).reshape([1,92]),\
                        np.asarray(h5['co2ConcLayers']).reshape([1,92]),\
                        np.asarray(h5['aerosolEffectiveRadius']).reshape([1,92,1]), np.asarray(h5['aerosolConcentration']).reshape([1,92,1]), h5['aerosolType'][()], \
                        np.asarray(h5['cloudEffectiveRadius']).reshape([1,92,1]), np.asarray(h5['cloudConcentration']).reshape([1,92,1]), h5['cloudType'][()], np.asarray(h5['cloudFraction']).reshape([1,92]), h5['climatology'][()], \
                        np.asarray(h5['surfaceTemperatures']).reshape([1,4]), np.asarray(h5['surfaceFractions']).reshape([1,4]), h5['LAI'][()], salinity, np.float(5.0), h5['windDirection10m'][()], h5['n_absorbers'][()],\
                        h5['landType'][()], h5['soilType'][()], h5['vegType'][()], h5['waterType'][()], h5['snowType'][()], h5['iceType'][()], 1 )

        
        diffK = kTb.flatten()-h5['Tb']
        diffKemis = kEmissivity.flatten()-h5['emissivity']
        
        diff = forwardTb.flatten()-h5['Tb']
        diffEmis = forwardEmissivity.flatten()-h5['emissivity']

        if ( all(np.abs(diffKemis) <= 1e-8)  and all(np.abs(diffK) <= 1e-8) and  all(np.abs(diffEmis) <= 1e-8)  and all(np.abs(diff) <= 1e-8) ):
            print ("Yay! we duplicated results from CRTM test program!")
        else:
            h5wav = h5py.File(os.path.join(thisDir,'cris_wavenumbers.h5'),'r')
            wavenumbers = np.asarray(h5wav['wavenumbers'])
            
            plt.figure()
            plt.plot(wavenumbers,diffK)
            plt.savefig( os.path.join(thisDir,c+'_spectrum_k_matrix.png') )

            plt.figure()
            plt.plot(wavenumbers,diffKemis)
            plt.savefig( os.path.join(thisDir,c+'_emissivity_k_matrix.png') ) 

            plt.figure()
            plt.plot(wavenumbers,forwardTb.flatten()-h5['Tb'])
            plt.savefig( os.path.join(thisDir,c+'_spectrum_forward.png') )

            plt.figure()
            plt.plot(wavenumbers,forwardEmissivity.flatten()-h5['emissivity'])
            plt.savefig( os.path.join(thisDir,c+'_emissivity_forward.png') ) 
            sys.exit("Boo! {} failed to pass a test. look at plots for details in {}.".format(c,thisDir))

if __name__ == "__main__":
    pathInfo = configparser.ConfigParser()
    pathInfo.read( os.path.join( parentDir, 'crtm.cfg' ) )
    coefficientPath = pathInfo['CRTM']['coeffs_dir']
    sensor_id = 'cris_npp' 
    main(coefficientPath, sensor_id)
 
